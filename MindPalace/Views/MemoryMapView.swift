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
    @State private var selectedPhotoId: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic

    private var visiblePhotos: [MemoryPhoto] {
        photos
            .filter { photo in
                photo.latitude != nil
                    && photo.longitude != nil
                    && (selectedSetId == nil || photo.setId == selectedSetId)
            }
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var selectedPhoto: MemoryPhoto? {
        visiblePhotos.first { $0.id == selectedPhotoId }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if visiblePhotos.isEmpty {
                ContentUnavailableView(
                    "地図に置いた写真がありません",
                    systemImage: "map",
                    description: Text("写真に場所を追加すると、ここに記憶スポットが並びます。")
                )
            } else {
                Map(position: $cameraPosition, selection: $selectedPhotoId) {
                    ForEach(visiblePhotos) { photo in
                        Annotation(photo.title, coordinate: coordinate(for: photo)) {
                            PhotoMapPin(
                                image: ImageStore.loadImage(named: photo.imagePath),
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
                .ignoresSafeArea(edges: .bottom)
            }

            VStack(spacing: 10) {
                Text("記憶マップ")
                    .font(.title2.weight(.bold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())

                SetFilterChips(
                    memorySets: memorySets,
                    selectedSetId: $selectedSetId
                )
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if let selectedPhoto {
                MapPreviewCard(
                    photo: selectedPhoto,
                    memorySet: memorySets.first { $0.id == selectedPhoto.setId },
                    theme: themes.first { $0.setId == selectedPhoto.setId },
                    noteCount: items.filter { $0.photoId == selectedPhoto.id }.count
                )
                .padding()
            }
        }
        .onAppear(perform: updateCameraIfNeeded)
        .onChange(of: selectedSetId) {
            selectedPhotoId = nil
            updateCameraIfNeeded()
        }
        .navigationBarTitleDisplayMode(.inline)
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

private struct SetFilterChips: View {
    let memorySets: [MemorySet]
    @Binding var selectedSetId: UUID?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "すべて",
                    isSelected: selectedSetId == nil
                ) {
                    selectedSetId = nil
                }

                ForEach(memorySets) { memorySet in
                    FilterChip(
                        title: memorySet.name,
                        isSelected: selectedSetId == memorySet.id
                    ) {
                        selectedSetId = memorySet.id
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(uiColor: .secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct PhotoMapPin: View {
    let image: UIImage?
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 54, height: 54)
                .shadow(color: .black.opacity(0.24), radius: 8, y: 3)

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 46, height: 46)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(.secondary.opacity(0.18))
                    .frame(width: 46, height: 46)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
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
        HStack(spacing: 12) {
            if let image = ImageStore.loadImage(named: photo.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(photo.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(memorySet?.name ?? "記憶セット")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Label("\(noteCount) メモ", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(spacing: 10) {
                if let memorySet {
                    NavigationLink {
                        MemorySetDetailView(memorySet: memorySet)
                    } label: {
                        Image(systemName: "rectangle.stack")
                    }
                    .buttonStyle(.bordered)
                }

                if let theme {
                    NavigationLink {
                        PhotoEditorView(photo: photo, theme: theme)
                    } label: {
                        Image(systemName: "arrow.up.right")
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
