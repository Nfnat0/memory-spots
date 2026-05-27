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
                            StickyNoteView(item: item)
                                .position(
                                    x: imageFrame.minX + item.x * imageFrame.width,
                                    y: imageFrame.minY + item.y * imageFrame.height
                                )
                                .gesture(dragGesture(for: item, in: imageFrame))
                                .onTapGesture {
                                    editingItem = item
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

                Button {
                    addNote()
                } label: {
                    Label("メモ追加", systemImage: "note.text.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(.regularMaterial)
        }
        .sheet(item: $editingItem) { item in
            NoteEditorView(item: item) {
                delete(item)
                editingItem = nil
            }
            .presentationDetents([.medium])
        }
    }

    private func addNote() {
        let item = MemoryItem(
            photoId: photo.id,
            themeId: theme.id,
            frontText: "新しいメモ",
            backText: "",
            x: 0.5,
            y: 0.5,
            orderIndex: themeItems.count
        )
        modelContext.insert(item)
        try? modelContext.save()
        editingItem = item
    }

    private func delete(_ item: MemoryItem) {
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
}

private struct StickyNoteView: View {
    let item: MemoryItem

    var body: some View {
        Text(item.frontText.isEmpty ? "メモ" : item.frontText)
            .font(.callout.weight(.semibold))
            .foregroundStyle(.black)
            .lineLimit(3)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 88, maxWidth: 150)
            .background(.yellow, in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
            .accessibilityLabel("メモ \(item.frontText)")
    }
}

private struct NoteEditorView: View {
    @Bindable var item: MemoryItem
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("表面") {
                    TextField("表面テキスト", text: $item.frontText, axis: .vertical)
                        .lineLimit(3...6)
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
                        dismiss()
                    }
                }
            }
        }
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
