import SwiftData
import SwiftUI
import UIKit

struct ReviewView: View {
    @Environment(\.modelContext) private var modelContext

    let memorySet: MemorySet

    @Query private var photos: [MemoryPhoto]
    @Query private var themes: [MemoryTheme]
    @Query private var items: [MemoryItem]

    @State private var currentIndex: Int
    @State private var selectedThemeId: UUID
    @State private var activeHelp: HelpTopic?

    init(memorySet: MemorySet, theme: MemoryTheme, initialPhoto: MemoryPhoto? = nil) {
        self.memorySet = memorySet

        let sortedPhotos = memorySet.photos.sorted { $0.orderIndex < $1.orderIndex }
        _currentIndex = State(initialValue: sortedPhotos.firstIndex { $0.id == initialPhoto?.id } ?? 0)
        _selectedThemeId = State(initialValue: theme.id)
    }

    private var orderedPhotos: [MemoryPhoto] {
        photos
            .filter { $0.setId == memorySet.id }
            .sorted { $0.orderIndex < $1.orderIndex }
    }

    private var setThemes: [MemoryTheme] {
        themes
            .filter { $0.setId == memorySet.id }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedTheme: MemoryTheme? {
        setThemes.first { $0.id == selectedThemeId } ?? setThemes.first
    }

    var body: some View {
        VStack(spacing: 0) {
            if let selectedTheme {
                if orderedPhotos.isEmpty {
                    ContentUnavailableView(
                        "No Notes to Review",
                        systemImage: "map",
                        description: Text("Add notes to this theme to walk through them in photo order.")
                    )
                } else {
                    TabView(selection: $currentIndex) {
                        if let lastPhoto = orderedPhotos.last {
                            ReviewPhotoPageView(
                                photo: lastPhoto,
                                theme: selectedTheme,
                                items: items.filter { $0.photoId == lastPhoto.id && $0.themeId == selectedTheme.id }
                            )
                            .tag(-1)
                        }

                        ForEach(Array(orderedPhotos.enumerated()), id: \.element.id) { index, photo in
                            ReviewPhotoPageView(
                                photo: photo,
                                theme: selectedTheme,
                                items: items.filter { $0.photoId == photo.id && $0.themeId == selectedTheme.id }
                            )
                            .tag(index)
                        }

                        if let firstPhoto = orderedPhotos.first {
                            ReviewPhotoPageView(
                                photo: firstPhoto,
                                theme: selectedTheme,
                                items: items.filter { $0.photoId == firstPhoto.id && $0.themeId == selectedTheme.id }
                            )
                            .tag(orderedPhotos.count)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .onChange(of: currentIndex) { _, newIndex in
                        loopReviewIndexIfNeeded(newIndex)
                    }
                    .overlay(alignment: .topLeading) {
                        Text(verbatim: "\(displayIndex + 1) / \(orderedPhotos.count)")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.regularMaterial, in: Capsule())
                            .padding()
                    }
                }
            } else {
                ContentUnavailableView("No Themes", systemImage: "tag")
            }
        }
        .background(NotebookBackground())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                ThemePickerMenu(themes: setThemes, selectedThemeId: $selectedThemeId)
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                HelpToolbarButton(topic: .review, activeHelp: $activeHelp)

                if let currentPhoto, let selectedTheme {
                    NavigationLink {
                        PhotoEditorView(photo: currentPhoto, theme: selectedTheme, photos: orderedPhotos)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                }
            }
        }
        .sheet(item: $activeHelp) { topic in
            HelpSheetView(topic: topic)
                .presentationDetents([.large])
        }
    }

    private var displayIndex: Int {
        guard !orderedPhotos.isEmpty else { return 0 }
        if currentIndex < 0 {
            return orderedPhotos.count - 1
        }
        if currentIndex >= orderedPhotos.count {
            return 0
        }
        return currentIndex
    }

    private var currentPhoto: MemoryPhoto? {
        guard orderedPhotos.indices.contains(displayIndex) else {
            return nil
        }
        return orderedPhotos[displayIndex]
    }

    private func loopReviewIndexIfNeeded(_ index: Int) {
        guard orderedPhotos.count > 1 else { return }
        if index < 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard currentIndex < 0 else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    currentIndex = orderedPhotos.count - 1
                }
            }
        } else if index >= orderedPhotos.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard currentIndex >= orderedPhotos.count else { return }
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    currentIndex = 0
                }
            }
        }
    }
}

struct ThemePickerMenu: View {
    let themes: [MemoryTheme]
    @Binding var selectedThemeId: UUID

    private var selectedThemeName: String {
        themes.first { $0.id == selectedThemeId }?.name ?? String(localized: "Theme")
    }

    var body: some View {
        Menu {
            ForEach(themes) { theme in
                Button {
                    selectedThemeId = theme.id
                } label: {
                    if theme.id == selectedThemeId {
                        Label(theme.name, systemImage: "checkmark")
                    } else {
                        Text(theme.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(selectedThemeName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .frame(minWidth: 120, maxWidth: 220)
            .foregroundStyle(PalaceStyle.ink)
            .contentShape(Rectangle())
        }
        .disabled(themes.count < 2)
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
        Text(item.backText.isEmpty ? String(localized: "Answer is empty.") : item.backText)
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
