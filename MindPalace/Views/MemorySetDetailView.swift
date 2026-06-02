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
    @Query private var items: [MemoryItem]
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

    private var headerNoteCount: Int {
        let photoIds = Set(setPhotos.map(\.id))
        return items.filter { photoIds.contains($0.photoId) }.count
    }

    var body: some View {
        List {
            headerSection
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
                    Label("写真を追加", systemImage: "photo.badge.plus")
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
                ContentUnavailableView("テーマがありません", systemImage: "tag")
            }
        }
        .sheet(isPresented: $isAddingTheme) {
            SetNameEditor(title: "テーマを作成", initialName: "") { name in
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

    private var headerSection: some View {
        Section {
            MemorySetHeaderCard(
                memorySet: memorySet,
                photoCount: setPhotos.count,
                themeCount: setThemes.count,
                noteCount: headerNoteCount
            )
        }
        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private var themeSection: some View {
        Section {
            if setThemes.isEmpty {
                Button("デフォルトテーマを作成") {
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
                        }
                    }
                }

                HStack {
                    Button("テーマ追加") {
                        isAddingTheme = true
                    }

                    Spacer()

                    Button("選択テーマを削除", role: .destructive) {
                        deleteSelectedTheme()
                    }
                    .disabled(setThemes.count < 2 || selectedTheme == nil)
                }
            }
        } header: {
            Text("ノートの切り口")
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
                    Label("メモをめぐる", systemImage: "play.circle")
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
                    "写真がありません",
                    systemImage: "photo.on.rectangle",
                    description: Text("この旅の道しるべになる写真を追加してください。")
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
        } header: {
            Text("道しるべ写真")
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
        createTheme(named: "デフォルト")
    }

    private func createTheme(named name: String) {
        let theme = MemoryTheme(setId: memorySet.id, name: name)
        theme.set = memorySet
        modelContext.insert(theme)
        selectedThemeId = theme.id
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteSelectedTheme() {
        guard let selectedTheme else {
            return
        }
        modelContext.delete(selectedTheme)
        selectedThemeId = setThemes.first { $0.id != selectedTheme.id }?.id
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

private struct MemorySetHeaderCard: View {
    let memorySet: MemorySet
    let photoCount: Int
    let themeCount: Int
    let noteCount: Int

    var body: some View {
        HStack(spacing: 14) {
            NotebookHeroImage()
                .frame(width: 108, height: 96)
                .shadow(color: PalaceStyle.ink.opacity(0.12), radius: 8, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                Text(memorySet.name)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(PalaceStyle.ink)
                    .lineLimit(2)
                Text("写真をたどって、頭の中に小さな散歩道を作ります。")
                    .font(.caption)
                    .foregroundStyle(PalaceStyle.mutedInk)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    NotebookLabel(text: "\(photoCount)", systemImage: "photo")
                    NotebookLabel(text: "\(themeCount)", systemImage: "tag")
                    NotebookLabel(text: "\(noteCount)", systemImage: "note.text")
                }
            }
        }
        .padding(12)
        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(PalaceStyle.paperDeep.opacity(0.42), lineWidth: 1)
        }
    }
}

private struct PhotoRouteRow: View {
    let photo: MemoryPhoto
    let noteCount: Int
    let onEditLocation: () -> Void
    let onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            PhotoRow(photo: photo, noteCount: noteCount)

            HStack {
                Button {
                    onEditLocation()
                } label: {
                    Label(
                        photo.latitude == nil ? "場所を追加する" : "場所を変更する",
                        systemImage: photo.latitude == nil ? "mappin.and.ellipse" : "mappin"
                    )
                    .font(.caption)
                }
                .buttonStyle(.borderless)

                Spacer()

                Button {
                    onOpen()
                } label: {
                    Label("開く", systemImage: "arrow.up.right")
                        .font(.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 4)
        }
    }
}

private struct PhotoRow: View {
    let photo: MemoryPhoto
    let noteCount: Int

    var body: some View {
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
                Label("\(noteCount) メモ", systemImage: "note.text")
                    .font(.subheadline)
                    .foregroundStyle(PalaceStyle.mutedInk)
            }
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
                        Label("ライブラリから選択", systemImage: "photo.on.rectangle")
                    }

                    Button {
                        isShowingCamera = true
                    } label: {
                        Label("カメラで撮影", systemImage: "camera")
                    }
                }

                if let coordinate = locationProvider.latestCoordinate {
                    Section("位置情報") {
                        Text("カメラ撮影ではこの場所に保存します。")
                            .foregroundStyle(.secondary)
                        Text("緯度 \(coordinate.latitude.formatted(.number.precision(.fractionLength(4))))")
                        Text("経度 \(coordinate.longitude.formatted(.number.precision(.fractionLength(4))))")
                    }
                } else {
                    Section("位置情報") {
                        Text("場所なしでも写真を保存できます。あとから地図で場所を追加できます。")
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
            .navigationTitle("写真を追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
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
                errorMessage = "画像を読み込めませんでした。"
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
                title: "場所写真 \(nextOrderIndex + 1)",
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
