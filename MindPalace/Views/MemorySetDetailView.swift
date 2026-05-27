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

    var body: some View {
        List {
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
                                    Text(theme.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedTheme?.id == theme.id ? Color.accentColor : Color(uiColor: .secondarySystemBackground),
                                            in: Capsule()
                                        )
                                        .foregroundStyle(selectedTheme?.id == theme.id ? .white : .primary)
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
                Text("テーマ")
            }

            Section {
                if let selectedTheme {
                    NavigationLink {
                        ReviewView(memorySet: memorySet, theme: selectedTheme)
                    } label: {
                        Label("メモをめぐる", systemImage: "play.circle")
                    }
                    .disabled(reviewItems(for: selectedTheme).isEmpty)
                }
            }

            Section {
                if setPhotos.isEmpty {
                    ContentUnavailableView(
                        "写真がありません",
                        systemImage: "photo",
                        description: Text("ライブラリまたはカメラから場所写真を追加してください。")
                    )
                } else {
                    ForEach(setPhotos) { photo in
                        if let selectedTheme {
                            VStack(alignment: .leading, spacing: 8) {
                                PhotoRow(
                                    photo: photo,
                                    noteCount: items.filter {
                                        $0.photoId == photo.id && $0.themeId == selectedTheme.id
                                    }.count
                                )

                                HStack {
                                    Button {
                                        editingLocationPhoto = photo
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
                                        openingPhoto = photo
                                    } label: {
                                        Label("開く", systemImage: "arrow.up.right")
                                            .font(.caption.weight(.semibold))
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            PhotoRow(photo: photo, noteCount: 0)
                        }
                    }
                    .onDelete(perform: deletePhotos)
                    .onMove(perform: movePhotos)
                }
            } header: {
                Text("場所写真")
            }
        }
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

    private func ensureThemeSelection() {
        guard !setThemes.isEmpty else {
            selectedThemeId = nil
            return
        }
        if selectedTheme == nil {
            selectedThemeId = setThemes.first?.id
        }
    }

    private func createDefaultTheme() {
        createTheme(named: "デフォルト")
    }

    private func createTheme(named name: String) {
        let theme = MemoryTheme(setId: memorySet.id, name: name)
        modelContext.insert(theme)
        selectedThemeId = theme.id
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func deleteSelectedTheme() {
        guard let selectedTheme else {
            return
        }
        let themeItems = items.filter { $0.themeId == selectedTheme.id }
        let itemIds = Set(themeItems.map(\.id))
        for result in reviewResults where itemIds.contains(result.itemId) {
            modelContext.delete(result)
        }
        for item in themeItems {
            modelContext.delete(item)
        }
        modelContext.delete(selectedTheme)
        selectedThemeId = setThemes.first { $0.id != selectedTheme.id }?.id
        memorySet.updatedAt = Date()
        try? modelContext.save()
    }

    private func deletePhotos(at offsets: IndexSet) {
        for index in offsets {
            let photo = setPhotos[index]
            let photoItems = items.filter { $0.photoId == photo.id }
            let itemIds = Set(photoItems.map(\.id))
            for result in reviewResults where itemIds.contains(result.itemId) {
                modelContext.delete(result)
            }
            for item in photoItems {
                modelContext.delete(item)
            }
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
        let photoIds = Set(setPhotos.map(\.id))
        return items.filter { item in
            item.themeId == theme.id && photoIds.contains(item.photoId)
        }
    }
}

private struct PhotoRow: View {
    let photo: MemoryPhoto
    let noteCount: Int

    var body: some View {
        HStack(spacing: 12) {
            if let image = ImageStore.loadImage(named: photo.imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.2))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(photo.title)
                    .font(.headline)
                Label("\(noteCount)", systemImage: "note.text")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
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
