import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PhotoEditorView: View {
    @Environment(\.modelContext) private var modelContext

    let photo: MemoryPhoto
    let theme: MemoryTheme
    let photos: [MemoryPhoto]

    @Query private var items: [MemoryItem]
    @Query private var themes: [MemoryTheme]

    @State private var editingItem: MemoryItem?
    @State private var selectedPageIndex: Int
    @State private var selectedThemeId: UUID
    @State private var isImagePickerPresented = false
    @State private var editingLocationPhoto: MemoryPhoto?
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var activeHelp: HelpTopic?

    init(photo: MemoryPhoto, theme: MemoryTheme, photos: [MemoryPhoto]? = nil) {
        self.photo = photo
        self.theme = theme
        self.photos = photos?.isEmpty == false ? photos! : [photo]
        _selectedPageIndex = State(initialValue: self.photos.firstIndex { $0.id == photo.id } ?? 0)
        _selectedThemeId = State(initialValue: theme.id)
    }

    private var currentPhoto: MemoryPhoto {
        guard !photos.isEmpty else { return photo }
        return photos[displayIndex]
    }

    private var setThemes: [MemoryTheme] {
        themes
            .filter { $0.setId == currentPhoto.setId }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedTheme: MemoryTheme {
        setThemes.first { $0.id == selectedThemeId } ?? theme
    }

    private func themeItems(for photo: MemoryPhoto) -> [MemoryItem] {
        items
            .filter { $0.photoId == photo.id && $0.themeId == selectedTheme.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        Group {
            if photos.count > 1 {
                TabView(selection: $selectedPageIndex) {
                    if let lastPhoto = photos.last {
                        PhotoEditorCanvas(
                            photo: lastPhoto,
                            items: themeItems(for: lastPhoto),
                            editingItem: $editingItem,
                            onDelete: delete,
                            onSave: { try? modelContext.save() }
                        )
                        .tag(-1)
                    }

                    ForEach(photos) { pagePhoto in
                        let index = photos.firstIndex { $0.id == pagePhoto.id } ?? 0

                        PhotoEditorCanvas(
                            photo: pagePhoto,
                            items: themeItems(for: pagePhoto),
                            editingItem: $editingItem,
                            onDelete: delete,
                            onSave: { try? modelContext.save() }
                        )
                        .tag(index)
                    }

                    if let firstPhoto = photos.first {
                        PhotoEditorCanvas(
                            photo: firstPhoto,
                            items: themeItems(for: firstPhoto),
                            editingItem: $editingItem,
                            onDelete: delete,
                            onSave: { try? modelContext.save() }
                        )
                        .tag(photos.count)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .onChange(of: selectedPageIndex) { _, newIndex in
                    loopPhotoIndexIfNeeded(newIndex)
                }
            } else {
                PhotoEditorCanvas(
                    photo: currentPhoto,
                    items: themeItems(for: currentPhoto),
                    editingItem: $editingItem,
                    onDelete: delete,
                    onSave: { try? modelContext.save() }
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ThemePickerMenu(themes: setThemes, selectedThemeId: $selectedThemeId)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                HelpToolbarButton(topic: .photoEditor, activeHelp: $activeHelp)

                Button {
                    editingLocationPhoto = currentPhoto
                } label: {
                    Image(systemName: currentPhoto.latitude == nil ? "mappin.and.ellipse" : "mappin")
                }
                .accessibilityLabel(
                    currentPhoto.latitude == nil
                        ? String(localized: "Add Location")
                        : String(localized: "Change Location")
                )
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ForEach(MemoryItemType.allCases) { type in
                        Button {
                            if type == .image {
                                isImagePickerPresented = true
                            } else {
                                addNote(type: type)
                            }
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: type.systemImage)
                                    .font(.system(size: 20, weight: .bold))
                                Text(type.title)
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(PalaceStyle.paperDeep.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(PalaceStyle.ink)
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(PalaceStyle.paperDeep.opacity(0.8), lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .background(.ultraThinMaterial)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(PalaceStyle.paperDeep.opacity(0.45))
                    .frame(height: 1)
            }
        }
        .photosPicker(isPresented: $isImagePickerPresented, selection: $selectedImageItem, matching: .images)
        .onChange(of: selectedImageItem) {
            guard let selectedImageItem else {
                return
            }
            Task {
                await addImageNote(from: selectedImageItem)
                self.selectedImageItem = nil
            }
        }
        .sheet(isPresented: Binding(get: { editingItem != nil }, set: { if !$0 { editingItem = nil } })) {
            if let item = editingItem {
                NoteEditorView(item: item) {
                    delete(item)
                    editingItem = nil
                }
                .presentationDetents([.large])
            }
        }
        .sheet(item: $editingLocationPhoto) { photo in
            LocationEditorView(photo: photo)
        }
        .sheet(item: $activeHelp) { topic in
            HelpSheetView(topic: topic)
                .presentationDetents([.large])
        }
    }

    private var displayIndex: Int {
        guard !photos.isEmpty else { return 0 }
        if selectedPageIndex < 0 {
            return photos.count - 1
        }
        if selectedPageIndex >= photos.count {
            return 0
        }
        return selectedPageIndex
    }

    private func loopPhotoIndexIfNeeded(_ index: Int) {
        guard photos.count > 1 else { return }
        if index < 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard selectedPageIndex < 0 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selectedPageIndex = photos.count - 1
                }
            }
        } else if index >= photos.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard selectedPageIndex >= photos.count else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    selectedPageIndex = 0
                }
            }
        }
    }

    private func addNote(type: MemoryItemType) {
        let photo = currentPhoto
        let item = MemoryItem(
            photoId: photo.id,
            themeId: selectedTheme.id,
            type: type,
            frontText: "",
            backText: "",
            colorName: type == .stickyText ? "yellow" : nil,
            iconName: type == .icon ? "star.fill" : nil,
            rotation: type == .arrow ? -8 : 0,
            scale: type == .arrow ? 1.1 : 1,
            x: 0.5,
            y: 0.5,
            orderIndex: themeItems(for: photo).count
        )
        item.photo = photo
        item.theme = selectedTheme
        modelContext.insert(item)
        try? modelContext.save()
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        editingItem = item
    }

    private func addImageNote(from pickerItem: PhotosPickerItem) async {
        do {
            guard let data = try await pickerItem.loadTransferable(type: Data.self) else {
                return
            }
            let photo = currentPhoto
            let imagePath = try ImageStore.saveImageData(data)
            let item = MemoryItem(
                photoId: photo.id,
                themeId: selectedTheme.id,
                type: .image,
                frontText: "",
                backText: "",
                imagePath: imagePath,
                scale: 1,
                x: 0.5,
                y: 0.5,
                orderIndex: themeItems(for: photo).count
            )
            item.photo = photo
            item.theme = selectedTheme
            modelContext.insert(item)
            try? modelContext.save()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            editingItem = item
        } catch {
            assertionFailure("Failed to add image note: \(error)")
        }
    }

    private func delete(_ item: MemoryItem) {
        if item.itemType == .image, let imagePath = item.imagePath {
            ImageStore.deleteImage(named: imagePath)
        }
        modelContext.delete(item)
        normalizeItemOrder()
        try? modelContext.save()
    }

    private func normalizeItemOrder() {
        for (index, item) in themeItems(for: currentPhoto).enumerated() {
            item.orderIndex = index
        }
    }
}

private struct PhotoEditorCanvas: View {
    let photo: MemoryPhoto
    let items: [MemoryItem]
    @Binding var editingItem: MemoryItem?
    let onDelete: (MemoryItem) -> Void
    let onSave: () -> Void

    @State private var draggingItemId: UUID?
    @State private var dragStart = CGPoint.zero
    @State private var uiImage: UIImage?
    @State private var zoomScale: CGFloat = 1.0
    @State private var lastZoomScale: CGFloat = 1.0
    @State private var panOffset: CGSize = .zero
    @State private var lastPanOffset: CGSize = .zero

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { val in
                let newScale = lastZoomScale * val
                zoomScale = min(max(newScale, 1.0), 4.0)
            }
            .onEnded { _ in
                lastZoomScale = zoomScale
            }
    }

    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { val in
                guard zoomScale > 1.0 else { return }
                panOffset = CGSize(
                    width: lastPanOffset.width + val.translation.width,
                    height: lastPanOffset.height + val.translation.height
                )
            }
            .onEnded { _ in
                lastPanOffset = panOffset
            }
    }

    var body: some View {
        Group {
            if let image = uiImage {
                GeometryReader { proxy in
                    let imageFrame = aspectFitFrame(imageSize: image.size, containerSize: proxy.size)

                    ZStack(alignment: .topLeading) {
                        PalaceStyle.paper.opacity(0.58)
                            .ignoresSafeArea()

                        ZStack(alignment: .topLeading) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: imageFrame.width, height: imageFrame.height)
                                .position(x: imageFrame.midX, y: imageFrame.midY)

                            ForEach(items) { item in
                                MemoryItemView(item: item)
                                    .position(
                                        x: imageFrame.minX + item.x * imageFrame.width,
                                        y: imageFrame.minY + item.y * imageFrame.height
                                    )
                                    .scaleEffect(item.scale)
                                    .rotationEffect(.degrees(item.rotation))
                                    .gesture(dragGesture(for: item, in: imageFrame))
                                    .onTapGesture {
                                        editingItem = item
                                    }
                                    .contextMenu {
                                        Button("Delete Note", role: .destructive) {
                                            onDelete(item)
                                        }
                                    }
                            }
                        }
                        .scaleEffect(zoomScale)
                        .offset(panOffset)
                        .gesture(
                            panGesture
                                .simultaneously(with: magnification)
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring()) {
                                if zoomScale > 1.0 {
                                    zoomScale = 1.0
                                    lastZoomScale = 1.0
                                    panOffset = .zero
                                    lastPanOffset = .zero
                                } else {
                                    zoomScale = 2.0
                                    lastZoomScale = 2.0
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NotebookBackground())
            }
        }
        .task(id: photo.imagePath) {
            uiImage = nil
            uiImage = await ImageLoader.shared.load(fileName: photo.imagePath)
        }
    }

    private func dragGesture(for item: MemoryItem, in imageFrame: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if draggingItemId != item.id {
                    draggingItemId = item.id
                    dragStart = CGPoint(x: item.x, y: item.y)
                }

                item.x = clamped(dragStart.x + (value.translation.width / zoomScale) / imageFrame.width)
                item.y = clamped(dragStart.y + (value.translation.height / zoomScale) / imageFrame.height)
                item.updatedAt = Date()
            }
            .onEnded { _ in
                draggingItemId = nil
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                onSave()
            }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0.05), 0.95)
    }

}

private struct NoteEditorView: View {
    @Bindable var item: MemoryItem
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            Form {
                Section(item.itemType.title) {
                    if item.itemType == .icon {
                        Picker("Icon", selection: iconBinding) {
                            Label("Star", systemImage: "star.fill").tag("star.fill")
                            Label("Cloud", systemImage: "cloud.fill").tag("cloud.fill")
                            Label("Key", systemImage: "key.fill").tag("key.fill")
                            Label("Flag", systemImage: "flag.fill").tag("flag.fill")
                        }
                    }

                    if item.itemType == .stickyText {
                        Picker("Color", selection: colorBinding) {
                            Text("Yellow").tag("yellow")
                            Text("Pink").tag("pink")
                            Text("Blue").tag("blue")
                            Text("Green").tag("green")
                        }
                        .pickerStyle(.segmented)
                    }

                    if item.itemType != .image && item.itemType != .arrow {
                        TextField("Display Text", text: $item.frontText, axis: .vertical)
                            .lineLimit(1...6)
                    }
                }

                Section("Answer") {
                    TextField("Answer Details", text: $item.backText, axis: .vertical)
                        .lineLimit(3...8)
                }

            }
            .scrollContentBackground(.hidden)
            .background(NotebookBackground())
            .navigationTitle("Edit Note")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Delete", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        item.updatedAt = Date()
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private var colorBinding: Binding<String> {
        Binding(
            get: { item.colorName ?? "yellow" },
            set: { item.colorName = $0 }
        )
    }

    private var iconBinding: Binding<String> {
        Binding(
            get: { item.iconName ?? "star.fill" },
            set: { item.iconName = $0 }
        )
    }
}
