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
    @State private var animatedSelectedPhoto: MemoryPhoto? = nil

    private var visiblePhotos: [MemoryPhoto] {
        if let selectedSetId {
            guard let selectedSet = memorySets.first(where: { $0.id == selectedSetId }) else { return [] }
            return selectedSet.photos
                .filter { $0.latitude != nil && $0.longitude != nil }
                .sorted { $0.createdAt < $1.createdAt }
        } else {
            return photos
                .filter { $0.latitude != nil && $0.longitude != nil }
                .sorted { $0.createdAt < $1.createdAt }
        }
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
                    Text("記憶マップ")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(PalaceStyle.ink)
                    Text("写真の道しるべをたどる")
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

                SetFilterChips(
                    memorySets: memorySets,
                    selectedSetId: $selectedSetId
                )
            }
            .padding(.top, 8)
        }
        .safeAreaInset(edge: .bottom) {
            if let animatedSelectedPhoto {
                MapPreviewCard(
                    photo: animatedSelectedPhoto,
                    memorySet: animatedSelectedPhoto.set,
                    theme: animatedSelectedPhoto.set?.themes.sorted(by: { $0.createdAt < $1.createdAt }).first,
                    noteCount: animatedSelectedPhoto.items.count
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
                    Text("まだ地図に置いた写真がありません")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(PalaceStyle.ink)
                    Text("写真に場所を追加すると、思い出すための道しるべがここに並びます。")
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
                .background(isSelected ? PalaceStyle.coral : .white.opacity(0.82), in: Capsule())
                .foregroundStyle(isSelected ? .white : PalaceStyle.ink)
                .overlay {
                    Capsule()
                        .stroke(isSelected ? .clear : PalaceStyle.paperDeep.opacity(0.5), lineWidth: 1)
                }
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
                Text(memorySet?.name ?? "旅のアルバム")
                    .font(.subheadline)
                    .foregroundStyle(PalaceStyle.mutedInk)
                    .lineLimit(1)
                Label("\(noteCount) メモ", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundStyle(PalaceStyle.sage)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(.white.opacity(0.6), lineWidth: 1)
        }
        .shadow(color: PalaceStyle.ink.opacity(0.16), radius: 14, y: 6)
    }
}
