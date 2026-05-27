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
                    Picker("現在のテーマ", selection: selectedThemeBinding) {
                        ForEach(setThemes) { theme in
                            Text(theme.name).tag(theme.id)
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
                        Label("復習を開始", systemImage: "play.circle")
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
                            NavigationLink {
                                PhotoEditorView(photo: photo, theme: selectedTheme)
                            } label: {
                                PhotoRow(
                                    photo: photo,
                                    noteCount: items.filter {
                                        $0.photoId == photo.id && $0.themeId == selectedTheme.id
                                    }.count
                                )
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
    }

    private var selectedThemeBinding: Binding<UUID> {
        Binding(
            get: { selectedTheme?.id ?? setThemes.first?.id ?? UUID() },
            set: { selectedThemeId = $0 }
        )
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
                        Text("緯度 \(coordinate.latitude.formatted(.number.precision(.fractionLength(4))))")
                        Text("経度 \(coordinate.longitude.formatted(.number.precision(.fractionLength(4))))")
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
                    save(image)
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
            save(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func save(_ image: UIImage) {
        do {
            let imagePath = try ImageStore.saveImage(image)
            let coordinate = locationProvider.latestCoordinate
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
}
