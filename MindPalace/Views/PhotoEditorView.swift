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

    private var themeItems: [MemoryItem] {
        items
            .filter { $0.photoId == photo.id && $0.themeId == theme.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        Group {
            if let image = ImageStore.loadImage(named: photo.imagePath) {
                GeometryReader { proxy in
                    let imageFrame = aspectFitFrame(imageSize: image.size, containerSize: proxy.size)

                    ZStack(alignment: .topLeading) {
                        Color.black.opacity(0.04)
                            .ignoresSafeArea()

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
                }
            } else {
                ContentUnavailableView(
                    "写真を読み込めません",
                    systemImage: "photo",
                    description: Text("保存済みの画像ファイルが見つかりませんでした。")
                )
            }
        }
        .navigationTitle(theme.name)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            HStack {
                Label("現在のテーマ: \(theme.name)", systemImage: "tag")
                    .font(.subheadline)
                    .lineLimit(1)

                Spacer()

                Menu {
                    Button {
                        addNote(type: .stickyText)
                    } label: {
                        Label("付箋", systemImage: MemoryItemType.stickyText.systemImage)
                    }

                    Button {
                        isImagePickerPresented = true
                    } label: {
                        Label("画像", systemImage: MemoryItemType.image.systemImage)
                    }

                    Button {
                        addNote(type: .icon)
                    } label: {
                        Label("アイコン", systemImage: MemoryItemType.icon.systemImage)
                    }

                    Button {
                        addNote(type: .numberLabel)
                    } label: {
                        Label("番号", systemImage: MemoryItemType.numberLabel.systemImage)
                    }

                    Button {
                        addNote(type: .arrow)
                    } label: {
                        Label("矢印", systemImage: MemoryItemType.arrow.systemImage)
                    }
                } label: {
                    Label("置く", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial)
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
        .sheet(item: $editingItem) { item in
            NoteEditorView(item: item) {
                delete(item)
                editingItem = nil
            }
            .presentationDetents([.medium])
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
        modelContext.insert(item)
        try? modelContext.save()
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
            modelContext.insert(item)
            try? modelContext.save()
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

                item.x = clamped(dragStart.x + value.translation.width / imageFrame.width)
                item.y = clamped(dragStart.y + value.translation.height / imageFrame.height)
                item.updatedAt = Date()
            }
            .onEnded { _ in
                draggingItemId = nil
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

private struct MemoryItemView: View {
    let item: MemoryItem

    var body: some View {
        Group {
            switch item.itemType {
            case .stickyText:
                Text(item.frontText.isEmpty ? "メモ" : item.frontText)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.black)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .frame(minWidth: 88, maxWidth: 150)
                    .background(stickyColor, in: RoundedRectangle(cornerRadius: 8))
            case .image:
                if let imagePath = item.imagePath, let image = ImageStore.loadImage(named: imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 86)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Label("画像", systemImage: "photo")
                        .padding(12)
                        .background(.white, in: RoundedRectangle(cornerRadius: 8))
                }
            case .icon:
                VStack(spacing: 4) {
                    Image(systemName: item.iconName ?? "star.fill")
                        .font(.system(size: 34, weight: .bold))
                    if !item.frontText.isEmpty {
                        Text(item.frontText)
                            .font(.caption.weight(.semibold))
                    }
                }
                .foregroundStyle(.white)
                .padding(12)
                .background(.blue.gradient, in: Circle())
            case .numberLabel:
                Text(item.frontText.isEmpty ? "1" : item.frontText)
                    .font(.title2.weight(.black))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.orange.gradient, in: Circle())
            case .arrow:
                Image(systemName: "arrow.right")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(.red)
            }
        }
        .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
        .accessibilityLabel(item.itemType.title)
    }

    private var stickyColor: Color {
        switch item.colorName {
        case "pink":
            .pink.opacity(0.78)
        case "blue":
            .cyan.opacity(0.76)
        case "green":
            .green.opacity(0.72)
        default:
            .yellow
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

private extension MemoryItem {
    var itemType: MemoryItemType {
        MemoryItemType(rawValue: type) ?? .stickyText
    }
}

func aspectFitFrame(imageSize: CGSize, containerSize: CGSize) -> CGRect {
    guard imageSize.width > 0, imageSize.height > 0, containerSize.width > 0, containerSize.height > 0 else {
        return .zero
    }

    let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
    let width = imageSize.width * scale
    let height = imageSize.height * scale
    return CGRect(
        x: (containerSize.width - width) / 2,
        y: (containerSize.height - height) / 2,
        width: width,
        height: height
    )
}
