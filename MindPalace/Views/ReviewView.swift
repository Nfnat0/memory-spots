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

    private var orderedPhotos: [MemoryPhoto] {
        photos
            .filter { $0.setId == memorySet.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    var body: some View {
        VStack(spacing: 0) {
            if orderedPhotos.isEmpty {
                ContentUnavailableView(
                    "めぐるメモがありません",
                    systemImage: "map",
                    description: Text("このテーマにメモを置くと、写真の道順でたどれます。")
                )
            } else {
                TabView(selection: $currentIndex) {
                    ForEach(Array(orderedPhotos.enumerated()), id: \.element.id) { index, photo in
                        ReviewPhotoPageView(
                            photo: photo,
                            theme: theme,
                            items: items.filter { $0.photoId == photo.id && $0.themeId == theme.id }
                        )
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .overlay(alignment: .topLeading) {
                    Text("\(currentIndex + 1) / \(orderedPhotos.count)")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(.regularMaterial, in: Capsule())
                        .padding()
                }
            }
        }
        .background(NotebookBackground())
        .navigationTitle(orderedPhotos.indices.contains(currentIndex) ? orderedPhotos[currentIndex].title : theme.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ReviewPhotoPageView: View {
    let photo: MemoryPhoto
    let theme: MemoryTheme
    let items: [MemoryItem]

    @State private var uiImage: UIImage? = nil
    @State private var revealedItemIds: Set<UUID> = []

    var body: some View {
        GeometryReader { proxy in
            if let image = uiImage {
                let imageFrame = aspectFitFrame(imageSize: image.size, containerSize: proxy.size)

                ZStack(alignment: .topLeading) {
                    PalaceStyle.paper.opacity(0.58)

                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageFrame.width, height: imageFrame.height)
                        .position(x: imageFrame.midX, y: imageFrame.midY)

                    ForEach(items) { item in
                        let isRevealed = revealedItemIds.contains(item.id)

                        Group {
                            if isRevealed {
                                RevealedMemoryItemView(item: item)
                            } else {
                                MemoryItemView(item: item, maskFrontText: false, isMiniature: false)
                            }
                        }
                        .scaleEffect(item.scale)
                        .rotationEffect(.degrees(item.rotation))
                        .position(
                            x: imageFrame.minX + item.x * imageFrame.width,
                            y: imageFrame.minY + item.y * imageFrame.height
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                                if isRevealed {
                                    revealedItemIds.remove(item.id)
                                } else {
                                    revealedItemIds.insert(item.id)
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxHeight: .infinity)
        .task(id: photo.imagePath) {
            uiImage = await ImageLoader.shared.load(fileName: photo.imagePath)
        }
    }
}

private struct RevealedMemoryItemView: View {
    let item: MemoryItem

    var body: some View {
        Text(item.backText.isEmpty ? "答えは未入力です。" : item.backText)
            .font(.callout.weight(.semibold))
            .foregroundStyle(PalaceStyle.ink)
            .lineLimit(6)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 88, maxWidth: 150)
            .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(PalaceStyle.coral, lineWidth: 2)
            }
            .shadow(color: .black.opacity(0.18), radius: 5, y: 2)
    }
}
