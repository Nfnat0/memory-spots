import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PhotoEditorView: View {
    @Environment(\.modelContext) private var modelContext

    let photo: MemoryPhoto
    let theme: MemoryTheme

    @Query private var items: [MemoryItem]

    @State private var editingItem: MemoryItem?
    @State private var draggingItemId: UUID?
    @State private var dragStart = CGPoint.zero
    @State private var isImagePickerPresented = false
    @State private var selectedImageItem: PhotosPickerItem?

    // Zoom & Pan states
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
            .onEnded { val in
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
            .onEnded { val in
                lastPanOffset = panOffset
            }
    }

    @State private var uiImage: UIImage? = nil

    private var themeItems: [MemoryItem] {
        items
            .filter { $0.photoId == photo.id && $0.themeId == theme.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        Group {
            if let image = uiImage {
                GeometryReader { proxy in
                    let imageFrame = aspectFitFrame(imageSize: image.size, containerSize: proxy.size)

                    ZStack(alignment: .topLeading) {
                        PalaceStyle.paper.opacity(0.58)
                            .ignoresSafeArea()

                        // A canvas to group the image and the items together, so they scale/offset as one.
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(width: imageFrame.width, height: imageFrame.height)
                                .position(x: imageFrame.midX, y: imageFrame.midY)

                            ForEach(themeItems) { item in
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
                                        Button("メモを削除", role: .destructive) {
                                            delete(item)
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
                ProgressView("読み込み中...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(NotebookBackground())
            }
        }
        .task {
            uiImage = await ImageLoader.shared.load(fileName: photo.imagePath)
        }
        .navigationTitle(theme.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                HStack {
                    Label("現在のテーマ: \(theme.name)", systemImage: "tag")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(PalaceStyle.mutedInk)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.5), in: Capsule())
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 4)

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
                .presentationDetents([.medium])
            }
        }
    }

    private func addNote(type: MemoryItemType) {
        let item = MemoryItem(
            photoId: photo.id,
            themeId: theme.id,
            type: type,
            frontText: defaultFrontText(for: type),
            backText: "",
            colorName: type == .stickyText ? "yellow" : nil,
            iconName: type == .icon ? "star.fill" : nil,
            rotation: type == .arrow ? -8 : 0,
            scale: type == .arrow ? 1.1 : 1,
            x: 0.5,
            y: 0.5,
            orderIndex: themeItems.count
        )
        item.photo = photo
        item.theme = theme
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
            let imagePath = try ImageStore.saveImageData(data)
            let item = MemoryItem(
                photoId: photo.id,
                themeId: theme.id,
                type: .image,
                frontText: "画像メモ",
                backText: "",
                imagePath: imagePath,
                scale: 1,
                x: 0.5,
                y: 0.5,
                orderIndex: themeItems.count
            )
            item.photo = photo
            item.theme = theme
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
        for (index, item) in themeItems.enumerated() {
            item.orderIndex = index
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
                try? modelContext.save()
            }
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0.05), 0.95)
    }

    private func defaultFrontText(for type: MemoryItemType) -> String {
        switch type {
        case .stickyText:
            "新しいメモ"
        case .image:
            "画像メモ"
        case .icon:
            "スター"
        case .numberLabel:
            "\(themeItems.filter { $0.itemType == .numberLabel }.count + 1)"
        case .arrow:
            "矢印"
        }
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
                        Picker("アイコン", selection: iconBinding) {
                            Label("スター", systemImage: "star.fill").tag("star.fill")
                            Label("雲", systemImage: "cloud.fill").tag("cloud.fill")
                            Label("鍵", systemImage: "key.fill").tag("key.fill")
                            Label("旗", systemImage: "flag.fill").tag("flag.fill")
                        }
                    }

                    if item.itemType == .stickyText {
                        Picker("色", selection: colorBinding) {
                            Text("黄色").tag("yellow")
                            Text("ピンク").tag("pink")
                            Text("水色").tag("blue")
                            Text("緑").tag("green")
                        }
                        .pickerStyle(.segmented)
                    }

                    if item.itemType != .image && item.itemType != .arrow {
                        TextField("表示テキスト", text: $item.frontText, axis: .vertical)
                            .lineLimit(1...6)
                    }
                }

                Section("答え") {
                    TextField("答えテキスト", text: $item.backText, axis: .vertical)
                        .lineLimit(3...8)
                }

                Section {
                    Button("メモを削除", role: .destructive) {
                        onDelete()
                        dismiss()
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(NotebookBackground())
            .navigationTitle("メモ編集")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") {
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
