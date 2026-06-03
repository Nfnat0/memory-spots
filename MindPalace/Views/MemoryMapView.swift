import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct MemoryMapView: View {
    @Query(sort: \MemorySet.updatedAt, order: .reverse) private var memorySets: [MemorySet]
    @Query private var photos: [MemoryPhoto]
    @Query private var themes: [MemoryTheme]
    @Query private var items: [MemoryItem]

    @State private var selectedSetId: UUID?
    @State private var selectedThemeId: UUID?
    @State private var albumSearchText = ""
    @State private var themeSearchText = ""
    @State private var selectedPhotoId: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var animatedSelectedPhoto: MemoryPhoto? = nil

    private var visiblePhotos: [MemoryPhoto] {
        var filteredPhotos: [MemoryPhoto]
        if let selectedSet {
            filteredPhotos = selectedSet.photos
        } else {
            filteredPhotos = photos
        }

        if let selectedThemeId {
            filteredPhotos = filteredPhotos.filter { photo in
                photo.items.contains { $0.themeId == selectedThemeId }
            }
        }

        return filteredPhotos
            .filter { $0.latitude != nil && $0.longitude != nil }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedSet: MemorySet? {
        guard let selectedSetId else { return nil }
        return memorySets.first { $0.id == selectedSetId }
    }

    private var selectedTheme: MemoryTheme? {
        guard let selectedThemeId else { return nil }
        return themes.first { $0.id == selectedThemeId }
    }

    private var selectedPhoto: MemoryPhoto? {
        visiblePhotos.first { $0.id == selectedPhotoId }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if visiblePhotos.isEmpty {
                MapEmptyState()
            } else {
                Map(position: $cameraPosition, selection: $selectedPhotoId) {
                    ForEach(visiblePhotos) { photo in
                        Annotation(photo.title, coordinate: coordinate(for: photo)) {
                            PhotoMapPin(
                                imagePath: photo.imagePath,
                                isSelected: selectedPhotoId == photo.id
                            )
                        }
                        .tag(photo.id)
                    }
                }
                .mapControls {
                    MapCompass()
                    MapUserLocationButton()
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .ignoresSafeArea(edges: .bottom)
            }

            VStack(spacing: 10) {
                VStack(spacing: 3) {
                    Text("Memory Map")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PalaceStyle.ink)
                    Text("Follow your memory path")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(PalaceStyle.mutedInk)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.58), lineWidth: 1)
                }

                SearchFilterPanel(
                    memorySets: memorySets,
                    themes: themes,
                    selectedSetId: $selectedSetId,
                    selectedThemeId: $selectedThemeId,
                    albumSearchText: $albumSearchText,
                    themeSearchText: $themeSearchText
                )
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if let animatedSelectedPhoto {
                MapPreviewCard(
                    photo: animatedSelectedPhoto,
                    memorySet: animatedSelectedPhoto.set,
                    noteCount: noteCount(for: animatedSelectedPhoto)
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding()
            }
        }
        .onAppear(perform: updateCameraIfNeeded)
        .onChange(of: selectedSetId) {
            if let selectedTheme, selectedTheme.setId != selectedSetId {
                selectedThemeId = nil
            }
            selectedPhotoId = nil
            withAnimation {
                animatedSelectedPhoto = nil
            }
            updateCameraIfNeeded()
        }
        .onChange(of: selectedPhotoId) { _, newValue in
            if newValue != nil {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                animatedSelectedPhoto = visiblePhotos.first { $0.id == newValue }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func noteCount(for photo: MemoryPhoto) -> Int {
        if let selectedThemeId {
            return photo.items.filter { $0.themeId == selectedThemeId }.count
        }
        return photo.items.count
    }

    private func updateCameraIfNeeded() {
        guard let firstPhoto = visiblePhotos.first else {
            return
        }
        cameraPosition = .region(
            MKCoordinateRegion(
                center: coordinate(for: firstPhoto),
                span: MKCoordinateSpan(latitudeDelta: 0.006, longitudeDelta: 0.006)
            )
        )
    }

    private func coordinate(for photo: MemoryPhoto) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: photo.latitude ?? 0,
            longitude: photo.longitude ?? 0
        )
    }
}

private struct MapEmptyState: View {
    var body: some View {
        ZStack {
            NotebookBackground()

            VStack(spacing: 18) {
                NotebookHeroImage()
                    .frame(width: 220, height: 180)
                    .shadow(color: PalaceStyle.ink.opacity(0.16), radius: 16, y: 8)

                VStack(spacing: 8) {
                    Text("No Waypoints Added")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PalaceStyle.ink)
                    Text("Add locations to your photos to see your memory trail on the map.")
                        .font(.subheadline)
                        .foregroundStyle(PalaceStyle.mutedInk)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 28)
            }
            .padding(.top, 56)
        }
    }
}

private struct SearchFilterPanel: View {
    let memorySets: [MemorySet]
    let themes: [MemoryTheme]
    @Binding var selectedSetId: UUID?
    @Binding var selectedThemeId: UUID?
    @Binding var albumSearchText: String
    @Binding var themeSearchText: String

    private var selectedSet: MemorySet? {
        guard let selectedSetId else { return nil }
        return memorySets.first { $0.id == selectedSetId }
    }

    private var selectedTheme: MemoryTheme? {
        guard let selectedThemeId else { return nil }
        return themes.first { $0.id == selectedThemeId }
    }

    private var albumMatches: [MemorySet] {
        let query = albumSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(memorySets.filter { $0.name.localizedStandardContains(query) }.prefix(6))
    }

    private var themeMatches: [MemoryTheme] {
        let query = themeSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(
            themes
                .filter { theme in
                    (selectedSetId == nil || theme.setId == selectedSetId)
                        && theme.name.localizedStandardContains(query)
                }
                .prefix(6)
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SelectedFilterChip(
                    title: selectedSet?.name ?? String(localized: "All Albums"),
                    systemImage: "rectangle.stack",
                    isActive: selectedSet != nil
                ) {
                    selectedSetId = nil
                    selectedThemeId = nil
                    albumSearchText = ""
                }

                SelectedFilterChip(
                    title: selectedTheme?.name ?? String(localized: "All Themes"),
                    systemImage: "tag",
                    isActive: selectedTheme != nil
                ) {
                    selectedThemeId = nil
                    themeSearchText = ""
                }
            }

            FilterSearchField(
                title: String(localized: "Search albums"),
                text: $albumSearchText,
                systemImage: "magnifyingglass"
            )

            if !albumMatches.isEmpty {
                FilterResultList {
                    ForEach(albumMatches) { memorySet in
                        FilterResultButton(title: memorySet.name, subtitle: "\(memorySet.photos.count) photos") {
                            selectedSetId = memorySet.id
                            selectedThemeId = nil
                            albumSearchText = ""
                            themeSearchText = ""
                        }
                    }
                }
            }

            FilterSearchField(
                title: String(localized: "Search themes"),
                text: $themeSearchText,
                systemImage: "tag"
            )

            if !themeMatches.isEmpty {
                FilterResultList {
                    ForEach(themeMatches) { theme in
                        FilterResultButton(title: theme.name, subtitle: theme.set?.name ?? String(localized: "Album")) {
                            selectedThemeId = theme.id
                            if selectedSetId == nil {
                                selectedSetId = theme.setId
                            }
                            themeSearchText = ""
                        }
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: 360)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.58), lineWidth: 1)
        }
        .padding(.horizontal, 12)
    }
}

private struct SelectedFilterChip: View {
    let title: String
    let systemImage: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .frame(maxWidth: .infinity)
                .background(isActive ? PalaceStyle.coral : .white.opacity(0.82), in: Capsule())
                .foregroundStyle(isActive ? .white : PalaceStyle.ink)
                .overlay {
                    Capsule()
                        .stroke(isActive ? .clear : PalaceStyle.paperDeep.opacity(0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
    }
}

private struct FilterSearchField: View {
    let title: String
    @Binding var text: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(PalaceStyle.mutedInk)
            TextField(title, text: $text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(PalaceStyle.mutedInk)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.subheadline)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.white.opacity(0.84), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct FilterResultList<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(PalaceStyle.paperDeep.opacity(0.5), lineWidth: 1)
        }
    }
}

private struct FilterResultButton: View {
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(PalaceStyle.ink)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(PalaceStyle.mutedInk)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(PalaceStyle.mutedInk)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

private struct PhotoMapPin: View {
    let imagePath: String
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.24), radius: 8, y: 3)
                .overlay {
                    Circle()
                        .stroke(isSelected ? PalaceStyle.coral : PalaceStyle.paperDeep, lineWidth: isSelected ? 4 : 2)
                }

            MemoryPhotoView(imagePath: imagePath) {
                Circle()
                    .fill(PalaceStyle.paperDeep.opacity(0.32))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(PalaceStyle.mutedInk)
                    }
            }
            .scaledToFill()
            .frame(width: 46, height: 46)
            .clipShape(Circle())
        }
        .scaleEffect(isSelected ? 1.18 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: isSelected)
    }
}

private struct MapPreviewCard: View {
    let photo: MemoryPhoto
    let memorySet: MemorySet?
    let noteCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let memorySet {
                NavigationLink {
                    MemorySetDetailView(memorySet: memorySet)
                } label: {
                    cardContent
                        .padding(.trailing, 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Open album \(memorySet.name)"))
            } else {
                cardContent
            }

            if let memorySet {
                NavigationLink {
                    MemorySetDetailView(memorySet: memorySet)
                } label: {
                    Label("Album", systemImage: "rectangle.stack")
                        .font(.caption.weight(.bold))
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(PalaceStyle.coral, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
                .padding(12)
                .accessibilityLabel(String(localized: "Open album details"))
            }
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: PalaceStyle.ink.opacity(0.16), radius: 14, y: 6)
    }

    private var cardContent: some View {
        HStack(spacing: 12) {
            MemoryPhotoView(imagePath: photo.imagePath) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 72, height: 72)
            }
            .scaledToFill()
            .frame(width: 72, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 5) {
                Text(photo.title)
                    .font(.headline)
                    .foregroundStyle(PalaceStyle.ink)
                    .lineLimit(1)
                Text(memorySet?.name ?? String(localized: "Albums"))
                    .font(.subheadline)
                    .foregroundStyle(PalaceStyle.mutedInk)
                    .lineLimit(1)
                Label("\(noteCount) notes", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(PalaceStyle.sage)
            }

            Spacer()
        }
        .padding(12)
    }
}
