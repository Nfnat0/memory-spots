import CoreLocation
import Photos
import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct MemorySetDetailView: View {
    @Environment(\.modelContext) private var modelContext

    let memorySet: MemorySet

    @Query private var photos: [MemoryPhoto]
    @Query private var themes: [MemoryTheme]
    @Query private var reviewResults: [ReviewResult]

    @State private var selectedThemeId: UUID?
    @State private var isAddingTheme = false
    @State private var isAddingPhoto = false
    @State private var editingLocationPhoto: MemoryPhoto?
    @State private var openingPhoto: MemoryPhoto?

    private var setPhotos: [MemoryPhoto] {
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
        let id = selectedThemeId ?? setThemes.first?.id
        return setThemes.first { $0.id == id }
    }

    var body: some View {
        List {
            themeSection
            reviewSection
            photosSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NotebookBackground())
        .navigationTitle(memorySet.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isAddingPhoto = true
                } label: {
                    Label("Add Photo", systemImage: "photo.badge.plus")
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .onAppear {
            ensureThemeSelection()
        }
        .onChange(of: setThemes.map(\.id)) {
            ensureThemeSelection()
        }
        .navigationDestination(item: $openingPhoto) { photo in
            if let selectedTheme {
                PhotoEditorView(photo: photo, theme: selectedTheme)
            } else {
                ContentUnavailableView("No Themes", systemImage: "tag")
            }
        }
        .sheet(isPresented: $isAddingTheme) {
            SetNameEditor(title: String(localized: "Create Theme"), initialName: "") { name in
                createTheme(named: name)
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isAddingPhoto) {
            AddPhotoSheet(memorySet: memorySet, nextOrderIndex: setPhotos.count)
                .presentationDetents([.medium, .large])
        }
        .sheet(item: $editingLocationPhoto) { photo in
            LocationEditorView(photo: photo)
        }
    }

    private var themeSection: some View {
        Section {
            if setThemes.isEmpty {
                Button("Create Default Theme") {
                    createDefaultTheme()
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(setThemes) { theme in
                            Button {
                                selectedThemeId = theme.id
                            } label: {
                                ThemeChip(title: theme.name, isSelected: isSelected(theme))
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete Theme", systemImage: "trash", role: .destructive) {
                                    deleteTheme(theme)
                                }
                                .disabled(setThemes.count < 2)
                            }
                        }

                        Button {
                            isAddingTheme = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(PalaceStyle.ink)
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.72), in: Circle())
                                .overlay {
                                    Circle()
                                        .stroke(PalaceStyle.paperDeep.opacity(0.5), lineWidth: 1)
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "Add Theme"))
                    }
                }
            }
        }
        .listRowBackground(Color.white.opacity(0.62))
    }

    @ViewBuilder
    private var reviewSection: some View {
        if let selectedTheme {
            Section {
                NavigationLink {
                    ReviewView(memorySet: memorySet, theme: selectedTheme)
                } label: {
                    Label("Review Notes", systemImage: "play.circle")
                }
                .disabled(reviewItems(for: selectedTheme).isEmpty)
            }
            .listRowBackground(Color.white.opacity(0.62))
        }
    }

    private var photosSection: some View {
        Section {
            if setPhotos.isEmpty {
                ContentUnavailableView(
                    "No Photos",
                    systemImage: "photo.on.rectangle",
                    description: Text("Add some photos to guide your memory path.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(setPhotos) { photo in
                    PhotoRouteRow(
                        photo: photo,
                        noteCount: selectedTheme.map { noteCount(for: photo, theme: $0) } ?? 0,
                        onEditLocation: { editingLocationPhoto = photo },
                        onOpen: { openingPhoto = photo }
                    )
                }
                .onDelete(perform: deletePhotos)
                .onMove(perform: movePhotos)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            }
        }
    }

    private func ensureThemeSelection() {
        guard !setThemes.isEmpty else {
            selectedThemeId = nil
            return
        }
        if selectedTheme == nil {
            selectedThemeId = setThemes.first?.id
        }
    }

    private func isSelected(_ theme: MemoryTheme) -> Bool {
        selectedTheme?.id == theme.id
    }

    private func noteCount(for photo: MemoryPhoto, theme: MemoryTheme) -> Int {
        photo.items.filter { $0.theme == theme }.count
    }

    private func createDefaultTheme() {
        createTheme(named: String(localized: "Default"))
    }

    private func createTheme(named name: String) {
        let theme = MemoryTheme(setId: memorySet.id, name: name)
        theme.set = memorySet
        modelContext.insert(theme)
        selectedThemeId = theme.id
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteTheme(_ theme: MemoryTheme) {
        let fallbackThemeId = setThemes.first { $0.id != theme.id }?.id
        let isDeletingSelectedTheme = selectedTheme?.id == theme.id

        modelContext.delete(theme)
        if isDeletingSelectedTheme {
            selectedThemeId = fallbackThemeId
        }
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func deletePhotos(at offsets: IndexSet) {
        for index in offsets {
            let photo = setPhotos[index]
            ImageStore.deleteImage(named: photo.imagePath)
            modelContext.delete(photo)
        }
        normalizePhotoOrder()
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func movePhotos(from source: IndexSet, to destination: Int) {
        var reordered = setPhotos
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, photo) in reordered.enumerated() {
            photo.orderIndex = index
        }
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func normalizePhotoOrder() {
        for (index, photo) in setPhotos.enumerated() {
            photo.orderIndex = index
        }
    }

    private func reviewItems(for theme: MemoryTheme) -> [MemoryItem] {
        setPhotos.flatMap { $0.items.filter { $0.theme == theme } }
    }
}

private struct ThemeChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? PalaceStyle.coral : .white.opacity(0.72), in: Capsule())
            .foregroundStyle(isSelected ? .white : PalaceStyle.ink)
            .overlay {
                Capsule()
                    .stroke(PalaceStyle.paperDeep.opacity(0.5), lineWidth: isSelected ? 0 : 1)
            }
    }
}

private struct PhotoRouteRow: View {
    let photo: MemoryPhoto
    let noteCount: Int
    let onEditLocation: () -> Void
    let onOpen: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 12) {
                MemoryPhotoView(imagePath: photo.imagePath) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.secondary.opacity(0.2))
                        .frame(width: 64, height: 64)
                        .overlay {
                            Image(systemName: "photo")
                                .foregroundStyle(.secondary)
                        }
                }
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(photo.title)
                        .font(.headline)
                        .foregroundStyle(PalaceStyle.ink)
                    Label("\(noteCount) notes", systemImage: "note.text")
                        .font(.subheadline)
                        .foregroundStyle(PalaceStyle.mutedInk)
                }

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onOpen()
            }

            Button {
                onEditLocation()
            } label: {
                Image(systemName: photo.latitude == nil ? "mappin.and.ellipse" : "mappin")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(PalaceStyle.sage)
                    .frame(width: 44, height: 44)
                    .background(PalaceStyle.sage.opacity(0.14), in: RoundedRectangle(cornerRadius: 8))
                    .accessibilityLabel(
                        photo.latitude == nil
                            ? String(localized: "Add Location")
                            : String(localized: "Change Location")
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(PalaceStyle.paperDeep.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct AddPhotoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let memorySet: MemorySet
    let nextOrderIndex: Int

    @StateObject private var locationProvider = LocationProvider()
    @State private var selectedItem: PhotosPickerItem?
    @State private var isShowingCamera = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("Take Photo", systemImage: "camera")
                    }
                }

                if let coordinate = locationProvider.latestCoordinate {
                    Section("Location") {
                        Text("Camera capture will be saved with this location.")
                            .foregroundStyle(.secondary)
                        Text("Latitude \(coordinate.latitude.formatted(.number.precision(.fractionLength(4))))")
                        Text("Longitude \(coordinate.longitude.formatted(.number.precision(.fractionLength(4))))")
                    }
                } else {
                    Section("Location") {
                        Text("You can save photos without a location and add it on the map later.")
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Add Photo")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                locationProvider.requestLocationIfPossible()
            }
            .onChange(of: selectedItem) {
                guard let selectedItem else {
                    return
                }
                Task {
                    await importPhoto(from: selectedItem)
                }
            }
            .sheet(isPresented: $isShowingCamera) {
                CameraPicker { image in
                    save(image, coordinate: locationProvider.latestCoordinate)
                }
            }
        }
    }

    private func importPhoto(from item: PhotosPickerItem) async {
        do {
            guard
                let data = try await item.loadTransferable(type: Data.self),
                let image = UIImage(data: data)
            else {
                errorMessage = String(localized: "Failed to load image.")
                return
            }
            save(image, coordinate: libraryCoordinate(for: item))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ image: UIImage, coordinate: CLLocationCoordinate2D?) {
        do {
            let imagePath = try ImageStore.saveImage(image)
            let photo = MemoryPhoto(
                setId: memorySet.id,
                title: String(localized: "Place Photo \(nextOrderIndex + 1)"),
                imagePath: imagePath,
                latitude: coordinate?.latitude,
                longitude: coordinate?.longitude,
                orderIndex: nextOrderIndex
            )
            photo.set = memorySet
            modelContext.insert(photo)
            memorySet.updatedAt = Date()
            try modelContext.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func libraryCoordinate(for item: PhotosPickerItem) -> CLLocationCoordinate2D? {
        guard let identifier = item.itemIdentifier else {
            return nil
        }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        return result.firstObject?.location?.coordinate
    }
}
