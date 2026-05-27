import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MemorySet.updatedAt, order: .reverse) private var memorySets: [MemorySet]
    @Query private var photos: [MemoryPhoto]
    @Query private var themes: [MemoryTheme]
    @Query private var items: [MemoryItem]
    @Query private var reviewResults: [ReviewResult]

    @State private var isAddingSet = false
    @State private var renamingSet: MemorySet?

    var body: some View {
        TabView {
            NavigationStack {
                MemoryMapView()
            }
            .tabItem {
                Label("記憶マップ", systemImage: "map")
            }

            setList
                .tabItem {
                    Label("アルバム", systemImage: "photo.stack")
                }
        }
        .task {
            SeedDataService.seedAWSExamSetIfNeeded(modelContext: modelContext)
        }
    }

    private var setList: some View {
        NavigationStack {
            List {
                if memorySets.isEmpty {
                    ContentUnavailableView(
                        "アルバムがありません",
                        systemImage: "photo.on.rectangle",
                        description: Text("写真とメモをまとめるテーマを作れます。")
                    )
                } else {
                    ForEach(memorySets) { memorySet in
                        NavigationLink {
                            MemorySetDetailView(memorySet: memorySet)
                        } label: {
                            MemorySetRow(
                                memorySet: memorySet,
                                photoCount: photos.filter { $0.setId == memorySet.id }.count,
                                themeCount: themes.filter { $0.setId == memorySet.id }.count
                            )
                        }
                        .swipeActions(edge: .leading) {
                            Button("名前変更") {
                                renamingSet = memorySet
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("削除", role: .destructive) {
                                delete(memorySet)
                            }
                        }
                    }
                }
            }
            .navigationTitle("アルバム")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingSet = true
                    } label: {
                        Label("アルバムを追加", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingSet) {
                SetNameEditor(title: "アルバムを作成", initialName: "") { name in
                    createSet(named: name)
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $renamingSet) { memorySet in
                SetNameEditor(title: "名前変更", initialName: memorySet.name) { name in
                    memorySet.name = name
                    memorySet.updatedAt = Date()
                    try? modelContext.save()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private func createSet(named name: String) {
        let memorySet = MemorySet(name: name)
        let theme = MemoryTheme(setId: memorySet.id, name: "デフォルト")
        modelContext.insert(memorySet)
        modelContext.insert(theme)
        try? modelContext.save()
    }

    private func delete(_ memorySet: MemorySet) {
        let setPhotos = photos.filter { $0.setId == memorySet.id }
        let setThemes = themes.filter { $0.setId == memorySet.id }
        let photoIds = Set(setPhotos.map(\.id))
        let themeIds = Set(setThemes.map(\.id))
        let setItems = items.filter { photoIds.contains($0.photoId) || themeIds.contains($0.themeId) }
        let itemIds = Set(setItems.map(\.id))

        for result in reviewResults where itemIds.contains(result.itemId) {
            modelContext.delete(result)
        }
        for item in setItems {
            modelContext.delete(item)
        }
        for photo in setPhotos {
            ImageStore.deleteImage(named: photo.imagePath)
            modelContext.delete(photo)
        }
        for theme in setThemes {
            modelContext.delete(theme)
        }
        modelContext.delete(memorySet)
        try? modelContext.save()
    }
}

private struct MemorySetRow: View {
    let memorySet: MemorySet
    let photoCount: Int
    let themeCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(memorySet.name)
                .font(.headline)
            HStack(spacing: 12) {
                Label("\(photoCount)", systemImage: "photo")
                Label("\(themeCount)", systemImage: "tag")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

struct SetNameEditor: View {
    let title: String
    let initialName: String
    let onSave: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    init(title: String, initialName: String, onSave: @escaping (String) -> Void) {
        self.title = title
        self.initialName = initialName
        self.onSave = onSave
        _name = State(initialValue: initialName)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("名前", text: $name)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
