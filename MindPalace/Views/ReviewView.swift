import SwiftData
import SwiftUI
import UIKit

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext

    let memorySet: MemorySet
    let theme: MemoryTheme

    @Query private var photos: [MemoryPhoto]
    @Query private var items: [MemoryItem]

    @State private var currentIndex = 0
    @State private var isAnswerVisible = false

    private var orderedPhotos: [MemoryPhoto] {
        photos
            .filter { $0.setId == memorySet.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var reviewItems: [(photo: MemoryPhoto, item: MemoryItem)] {
        orderedPhotos.flatMap { photo in
            items
                .filter { $0.photoId == photo.id && $0.themeId == theme.id }
                .sorted { $0.orderIndex < $1.orderIndex }
                .map { (photo, $0) }
        }
    }

    private var current: (photo: MemoryPhoto, item: MemoryItem)? {
        guard reviewItems.indices.contains(currentIndex) else {
            return nil
        }
        return reviewItems[currentIndex]
    }

    var body: some View {
        VStack(spacing: 0) {
            if let current {
                ReviewPhotoView(photo: current.photo, item: current.item)
                    .overlay(alignment: .topLeading) {
                        Text("\(currentIndex + 1) / \(reviewItems.count)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                            .padding()
                    }

                VStack(alignment: .leading, spacing: 16) {
                    Text(current.item.frontText)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        isAnswerVisible.toggle()
                    } label: {
                        Label(isAnswerVisible ? "答えを隠す" : "答えを表示", systemImage: isAnswerVisible ? "eye.slash" : "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if isAnswerVisible {
                        Text(current.item.backText.isEmpty ? "答えは未入力です。" : current.item.backText)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))

                        HStack {
                            ForEach(ReviewGrade.allCases) { grade in
                                Button(grade.title) {
                                    record(grade, for: current.item)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(tint(for: grade))
                            }
                        }
                    }
                }
                .padding()
                .background(.background)
            } else {
                ContentUnavailableView(
                    "復習するメモがありません",
                    systemImage: "checkmark.circle",
                    description: Text("このテーマにメモを追加してから復習してください。")
                )
            }
        }
        .navigationTitle(theme.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func record(_ grade: ReviewGrade, for item: MemoryItem) {
        modelContext.insert(ReviewResult(itemId: item.id, result: grade))
        try? modelContext.save()

        if currentIndex + 1 < reviewItems.count {
            currentIndex += 1
            isAnswerVisible = false
        } else {
            currentIndex = reviewItems.count
            isAnswerVisible = false
        }
    }

    private func tint(for grade: ReviewGrade) -> Color {
        switch grade {
        case .remembered:
            .green
        case .unsure:
            .orange
        case .forgot:
            .red
        }
    }
}

private struct ReviewPhotoView: View {
    let photo: MemoryPhoto
    let item: MemoryItem

    var body: some View {
        GeometryReader { proxy in
            if let image = ImageStore.loadImage(named: photo.imagePath) {
                let imageFrame = aspectFitFrame(imageSize: image.size, containerSize: proxy.size)

                ZStack(alignment: .topLeading) {
                    Color.black.opacity(0.04)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)

                    Circle()
                        .fill(.yellow)
                        .frame(width: 28, height: 28)
                        .shadow(radius: 4)
                        .position(
                            x: imageFrame.minX + item.x * imageFrame.width,
                            y: imageFrame.minY + item.y * imageFrame.height
                        )
                }
            } else {
                ContentUnavailableView("写真なし", systemImage: "photo")
            }
        }
        .frame(maxHeight: .infinity)
    }
}
