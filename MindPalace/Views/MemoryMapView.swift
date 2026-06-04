import CoreLocation
import MapKit
import SwiftData
import SwiftUI

struct MemoryMapView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MemorySet.updatedAt, order: .reverse) private var memorySets: [MemorySet]
    @Query private var photos: [MemoryPhoto]
    @Query private var themes: [MemoryTheme]
    @Query private var items: [MemoryItem]

    @State private var selectedSetId: UUID?
    @State private var selectedThemeId: UUID?
    @State private var filterSearchText = ""
    @State private var isSearchActive = false
    @State private var isAddingSet = false
    @State private var selectedPhotoId: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var animatedSelectedPhoto: MemoryPhoto? = nil
    @StateObject private var locationProvider = LocationProvider()
    @State private var didSetInitialCamera = false
    @State private var isCenteringOnUserLocation = false
    @FocusState private var isSearchFocused: Bool

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
                    UserAnnotation()

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
                }
                .mapStyle(.standard(elevation: .flat, pointsOfInterest: .excludingAll))
                .ignoresSafeArea(edges: .bottom)
            }

            VStack(spacing: 8) {
                MapSearchBar(
                    title: searchBarTitle,
                    searchText: $filterSearchText,
                    isSearchActive: $isSearchActive,
                    isSearchFocused: $isSearchFocused,
                    isFiltered: selectedSet != nil || selectedTheme != nil,
                    beginSearch: beginSearch,
                    clearFilters: clearFilters,
                    centerOnUserLocation: centerOnUserLocation
                )

                if isSearchActive && (!albumMatches.isEmpty || !themeMatches.isEmpty) {
                    FilterResultList {
                        ForEach(albumMatches) { memorySet in
                            FilterResultButton(title: memorySet.name, subtitle: String(localized: "\(memorySet.photos.count) photos")) {
                                selectedSetId = memorySet.id
                                selectedThemeId = nil
                                endSearch()
                            }
                        }

                        ForEach(themeMatches) { theme in
                            FilterResultButton(title: theme.name, subtitle: theme.set?.name ?? String(localized: "Album")) {
                                selectedThemeId = theme.id
                                selectedSetId = theme.setId
                                endSearch()
                            }
                        }
                    }
                    .frame(maxWidth: 406)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if let animatedSelectedPhoto {
                MapPreviewCard(
                    photo: animatedSelectedPhoto,
                    memorySet: animatedSelectedPhoto.set,
                    theme: editorTheme(for: animatedSelectedPhoto),
                    noteCount: noteCount(for: animatedSelectedPhoto)
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
                .padding()
            }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingSet = true
                } label: {
                    Label("Add Album", systemImage: "plus")
                }
                .accessibilityIdentifier("memoryMapAddAlbumButton")
            }
        }
        .sheet(isPresented: $isAddingSet) {
            SetNameEditor(title: String(localized: "Create Album"), initialName: "") { name in
                createSet(named: name)
            }
            .presentationDetents([.medium])
        }
        .onAppear {
            if !isLocationDisabledForUITests {
                locationProvider.requestLocationIfPossible()
            }
            updateInitialCameraIfNeeded()
        }
        .onReceive(locationProvider.$latestCoordinate) { _ in
            guard !isLocationDisabledForUITests else {
                return
            }
            updateInitialCameraIfNeeded()
            if isCenteringOnUserLocation {
                centerOnUserLocation()
            }
        }
        .onChange(of: selectedSetId) {
            if let selectedTheme, selectedTheme.setId != selectedSetId {
                selectedThemeId = nil
            }
            selectedPhotoId = nil
            withAnimation {
                animatedSelectedPhoto = nil
            }
            updateCameraForVisiblePhotosIfNeeded()
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

    private var albumMatches: [MemorySet] {
        let query = filterSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(memorySets.filter { $0.name.localizedStandardContains(query) }.prefix(6))
    }

    private var themeMatches: [MemoryTheme] {
        let query = filterSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        return Array(themes.filter { $0.name.localizedStandardContains(query) }.prefix(6))
    }

    private var searchBarTitle: String {
        if let selectedSet, let selectedTheme {
            return "\(selectedSet.name) / \(selectedTheme.name)"
        }

        if let selectedSet {
            return selectedSet.name
        }

        if let selectedTheme {
            return selectedTheme.name
        }

        return String(localized: "Search albums or tags")
    }

    private var isLocationDisabledForUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestingDisableLocation")
    }

    private func beginSearch() {
        isSearchActive = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            isSearchFocused = true
        }
    }

    private func endSearch() {
        filterSearchText = ""
        isSearchFocused = false
        isSearchActive = false
    }

    private func clearFilters() {
        selectedSetId = nil
        selectedThemeId = nil
        endSearch()
    }

    private func editorTheme(for photo: MemoryPhoto) -> MemoryTheme? {
        if let selectedTheme, selectedTheme.setId == photo.setId {
            return selectedTheme
        }

        return themes
            .filter { $0.setId == photo.setId }
            .sorted { $0.createdAt < $1.createdAt }
            .first
    }

    private func createSet(named name: String) {
        let memorySet = MemorySet(name: name)
        let theme = MemoryTheme(setId: memorySet.id, name: String(localized: "Default"))
        theme.set = memorySet
        modelContext.insert(memorySet)
        modelContext.insert(theme)
        try? modelContext.save()
    }

    private func updateInitialCameraIfNeeded() {
        guard !didSetInitialCamera else {
            return
        }

        if let coordinate = locationProvider.latestCoordinate {
            cameraPosition = .region(region(centeredAt: coordinate, latitudeDelta: 0.01, longitudeDelta: 0.01))
            didSetInitialCamera = true
            return
        }

        updateCameraForVisiblePhotosIfNeeded()
    }

    private func updateCameraForVisiblePhotosIfNeeded() {
        guard let firstPhoto = visiblePhotos.first else {
            return
        }
        cameraPosition = .region(
            region(centeredAt: coordinate(for: firstPhoto), latitudeDelta: 0.006, longitudeDelta: 0.006)
        )
    }

    private func centerOnUserLocation() {
        guard !isLocationDisabledForUITests else {
            return
        }

        locationProvider.requestLocationIfPossible()
        guard let coordinate = locationProvider.latestCoordinate else {
            isCenteringOnUserLocation = true
            return
        }

        isCenteringOnUserLocation = false
        withAnimation {
            cameraPosition = .region(region(centeredAt: coordinate, latitudeDelta: 0.01, longitudeDelta: 0.01))
        }
    }

    private func coordinate(for photo: MemoryPhoto) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: photo.latitude ?? 0,
            longitude: photo.longitude ?? 0
        )
    }

    private func region(centeredAt coordinate: CLLocationCoordinate2D, latitudeDelta: CLLocationDegrees, longitudeDelta: CLLocationDegrees) -> MKCoordinateRegion {
        MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
        )
    }
}

private struct CurrentLocationMapButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "location.fill")
                .font(.headline.weight(.semibold))
                .foregroundStyle(PalaceStyle.ink)
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(.white.opacity(0.58), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "Current Location"))
        .accessibilityIdentifier("memoryMapCurrentLocationButton")
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

private struct MapSearchBar: View {
    let title: String
    @Binding var searchText: String
    @Binding var isSearchActive: Bool
    @FocusState.Binding var isSearchFocused: Bool
    let isFiltered: Bool
    let beginSearch: () -> Void
    let clearFilters: () -> Void
    let centerOnUserLocation: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(PalaceStyle.mutedInk)

                if isSearchActive {
                    TextField("Search albums or tags", text: $searchText)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .focused($isSearchFocused)
                        .submitLabel(.search)
                        .accessibilityIdentifier("memoryMapUnifiedSearchField")
                } else {
                    Button(action: beginSearch) {
                        Text(title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isFiltered ? PalaceStyle.ink : PalaceStyle.mutedInk)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Search albums or tags"))
                    .accessibilityIdentifier("memoryMapSearchBar")
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
            .onTapGesture {
                if !isSearchActive {
                    beginSearch()
                }
            }

            if isFiltered {
                Button(action: clearFilters) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(PalaceStyle.mutedInk)
                        .frame(width: 36, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Clear filters"))
            }

            CurrentLocationMapButton(action: centerOnUserLocation)
        }
        .padding(8)
        .frame(maxWidth: 430)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.58), lineWidth: 1)
        }
        .padding(.horizontal, 12)
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
    let theme: MemoryTheme?
    let noteCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            if let theme {
                NavigationLink {
                    PhotoEditorView(photo: photo, theme: theme)
                } label: {
                    cardContent
                        .padding(.trailing, 56)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Open photo \(photo.title)"))
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
