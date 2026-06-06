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
    @State private var isEditingAlbum = false
    @State private var renamingTheme: MemoryTheme?
    @State private var deletingTheme: MemoryTheme?
    @State private var deletingPhoto: MemoryPhoto?
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
            photosSection
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(NotebookBackground())
        .navigationTitle(memorySet.name)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button(isEditingAlbum ? "Done" : "Edit") {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        isEditingAlbum.toggle()
                    }
                }

                if !isEditingAlbum {
                    Button {
                        isAddingPhoto = true
                    } label: {
                        Label("Add Photo", systemImage: "photo.badge.plus")
                    }
                }
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
                ReviewView(memorySet: memorySet, theme: selectedTheme, initialPhoto: photo)
            } else {
                ContentUnavailableView("No Themes", systemImage: "tag")
            }
        }
        .sheet(isPresented: $isAddingTheme) {
            SetNameEditor(title: String(localized: "Create Theme"), initialName: "") { name in
                createTheme(named: name)
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isAddingPhoto) {
            AddPhotoSheet(memorySet: memorySet, nextOrderIndex: setPhotos.count)
                .presentationDetents([.large])
        }
        .sheet(item: $renamingTheme) { theme in
            SetNameEditor(title: String(localized: "Rename"), initialName: theme.name) { name in
                renameTheme(theme, to: name)
            }
            .presentationDetents([.large])
        }
        .confirmationDialog(
            "Delete Theme?",
            isPresented: Binding(
                get: { deletingTheme != nil },
                set: { if !$0 { deletingTheme = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let deletingTheme {
                Button("Delete Theme", role: .destructive) {
                    deleteTheme(deletingTheme)
                    self.deletingTheme = nil
                }
            }
            Button("Cancel", role: .cancel) {
                deletingTheme = nil
            }
        } message: {
            Text("This will delete this theme and its notes.")
        }
        .confirmationDialog(
            "Delete Image?",
            isPresented: Binding(
                get: { deletingPhoto != nil },
                set: { if !$0 { deletingPhoto = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let deletingPhoto {
                Button("Delete Image", role: .destructive) {
                    deletePhoto(deletingPhoto)
                    self.deletingPhoto = nil
                }
            }
            Button("Cancel", role: .cancel) {
                deletingPhoto = nil
            }
        } message: {
            Text("This will delete this image and its notes.")
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
                            ThemeChip(
                                title: theme.name,
                                isSelected: isSelected(theme),
                                isEditing: isEditingAlbum,
                                canDelete: setThemes.count > 1
                            ) {
                                selectedThemeId = theme.id
                            } onRename: {
                                renamingTheme = theme
                            } onDelete: {
                                deletingTheme = theme
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(setPhotos) { photo in
                        photoTile(for: photo)
                    }
                }
                .padding(.vertical, 4)
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

    private func renameTheme(_ theme: MemoryTheme, to name: String) {
        theme.name = name
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

    @ViewBuilder
    private func photoTile(for photo: MemoryPhoto) -> some View {
        let index = setPhotos.firstIndex { $0.id == photo.id }

        PhotoGridTile(
            photo: photo,
            isEditing: isEditingAlbum,
            canMoveBackward: index.map { $0 > 0 } ?? false,
            canMoveForward: index.map { $0 < setPhotos.count - 1 } ?? false
        ) {
            if !isEditingAlbum {
                openingPhoto = photo
            }
        } onDelete: {
            deletingPhoto = photo
        } onMoveBackward: {
            movePhoto(photo, by: -1)
        } onMoveForward: {
            movePhoto(photo, by: 1)
        }
    }

    private func deletePhoto(_ photo: MemoryPhoto) {
        ImageStore.deleteImage(named: photo.imagePath)
        modelContext.delete(photo)
        normalizePhotoOrder()
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func movePhoto(_ photo: MemoryPhoto, by offset: Int) {
        guard let sourceIndex = setPhotos.firstIndex(where: { $0.id == photo.id })
        else {
            return
        }
        let targetIndex = sourceIndex + offset
        guard setPhotos.indices.contains(targetIndex) else {
            return
        }

        var reorderedPhotos = setPhotos
        reorderedPhotos.swapAt(sourceIndex, targetIndex)

        for (index, photo) in reorderedPhotos.enumerated() {
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

}

private struct ThemeChip: View {
    let title: String
    let isSelected: Bool
    let isEditing: Bool
    let canDelete: Bool
    let onSelect: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            if isEditing {
                Divider()
                    .frame(height: 18)
                    .overlay((isSelected ? Color.white : PalaceStyle.paperDeep).opacity(0.55))

                Button(action: onRename) {
                    Image(systemName: "pencil")
                        .font(.caption.weight(.bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "Rename"))

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.caption.weight(.bold))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .foregroundStyle(canDelete ? .red : PalaceStyle.mutedInk.opacity(0.45))
                .disabled(!canDelete)
                .accessibilityLabel(String(localized: "Delete"))
            }
        }
        .padding(.leading, 14)
        .padding(.trailing, isEditing ? 8 : 14)
        .padding(.vertical, 8)
        .background(isSelected ? PalaceStyle.coral : .white.opacity(0.72), in: Capsule())
        .foregroundStyle(isSelected ? .white : PalaceStyle.ink)
        .overlay {
            Capsule()
                .stroke(PalaceStyle.paperDeep.opacity(0.5), lineWidth: isSelected ? 0 : 1)
        }
        .contentShape(Capsule())
        .onTapGesture {
            if !isEditing {
                onSelect()
            }
        }
    }
}

private struct PhotoGridTile: View {
    let photo: MemoryPhoto
    let isEditing: Bool
    let canMoveBackward: Bool
    let canMoveForward: Bool
    let onOpen: () -> Void
    let onDelete: () -> Void
    let onMoveBackward: () -> Void
    let onMoveForward: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            Button(action: onOpen) {
                GeometryReader { proxy in
                    MemoryPhotoView(imagePath: photo.imagePath) {
                        Rectangle()
                            .fill(.secondary.opacity(0.2))
                            .overlay {
                                Image(systemName: "photo")
                                    .foregroundStyle(.secondary)
                            }
                    }
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.width)
                    .clipped()
                }
                .aspectRatio(1, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .disabled(isEditing)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if isEditing {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3.weight(.bold))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(.white, .red)
                        .background(Circle().fill(.white))
                }
                .buttonStyle(.plain)
                .offset(x: -7, y: -7)
                .accessibilityLabel(String(localized: "Delete"))

                Button(action: onMoveBackward) {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PalaceStyle.ink)
                        .frame(width: 34, height: 44)
                        .background(.white.opacity(0.92), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(PalaceStyle.paperDeep.opacity(0.55), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canMoveBackward)
                .opacity(canMoveBackward ? 1 : 0.36)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(.leading, 6)
                .accessibilityLabel(String(localized: "Move Image Earlier"))

                Button(action: onMoveForward) {
                    Image(systemName: "chevron.right")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(PalaceStyle.ink)
                        .frame(width: 34, height: 44)
                        .background(.white.opacity(0.92), in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(PalaceStyle.paperDeep.opacity(0.55), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .disabled(!canMoveForward)
                .opacity(canMoveForward ? 1 : 0.36)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .padding(.trailing, 6)
                .accessibilityLabel(String(localized: "Move Image Later"))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(PalaceStyle.paperDeep.opacity(0.42), lineWidth: 1)
        }
        .scaleEffect(isEditing ? 0.96 : 1)
        .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isEditing)
        .accessibilityLabel(String(localized: "Open photo"))
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
                title: "",
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
