import Foundation
import SwiftData
import SwiftUI

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \MemorySet.updatedAt, order: .reverse) private var memorySets: [MemorySet]
    @Query private var items: [MemoryItem]
    @Query private var reviewResults: [ReviewResult]

    @State private var isAddingSet = false
    @State private var albumSearchText = ""
    @State private var renamingSet: MemorySet?
    @State private var openingSet: MemorySet?
    @AppStorage("hasCompletedTutorial") private var hasCompletedTutorial = false

    var body: some View {
        TabView {
            NavigationStack {
                MemoryMapView()
            }
            .tabItem {
                Label("Memory Map", systemImage: "map")
            }

            setList
                .tabItem {
                    Label("Albums", systemImage: "photo.stack")
                }
        }
        .task {
            if ProcessInfo.processInfo.arguments.contains("-AppStoreScreenshotData") {
                SeedDataService.seedAppStoreScreenshotSetsIfNeeded(modelContext: modelContext)
            } else {
                SeedDataService.seedAWSExamSetIfNeeded(modelContext: modelContext)
            }
        }
        .sheet(isPresented: Binding(get: { !hasCompletedTutorial && !isSkippingTutorialForUITests }, set: { _ in })) {
            TutorialView {
                hasCompletedTutorial = true
            }
            .interactiveDismissDisabled()
        }
    }

    private var isSkippingTutorialForUITests: Bool {
        ProcessInfo.processInfo.arguments.contains("-UITestingSkipTutorial")
    }

    private var setList: some View {
        NavigationStack {
            List {
                if memorySets.isEmpty {
                    ContentUnavailableView(
                        "No Albums",
                        systemImage: "map",
                        description: Text("Pin photos on the map to create waypoints for your memory palace.")
                    )
                    .listRowBackground(Color.clear)
                } else if filteredMemorySets.isEmpty {
                    ContentUnavailableView(
                        "No Albums",
                        systemImage: "magnifyingglass",
                        description: Text("No albums match your search.")
                    )
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(filteredMemorySets) { memorySet in
                        Button {
                            openingSet = memorySet
                        } label: {
                            MemorySetRow(
                                memorySet: memorySet,
                                photoCount: memorySet.photos.count,
                                themeCount: memorySet.themes.count,
                                thumbnailImagePath: memorySet.photos
                                    .sorted { $0.orderIndex < $1.orderIndex }
                                    .first?
                                    .imagePath
                            )
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .swipeActions(edge: .leading) {
                            Button("Rename") {
                                renamingSet = memorySet
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing) {
                            Button("Delete", role: .destructive) {
                                delete(memorySet)
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(NotebookBackground())
            .navigationTitle("Albums")
            .searchable(
                text: $albumSearchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: Text("Search albums")
            )
            .navigationDestination(item: $openingSet) { memorySet in
                MemorySetDetailView(memorySet: memorySet)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingSet = true
                    } label: {
                        Label("Add Album", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingSet) {
                SetNameEditor(title: String(localized: "Create Album"), initialName: "") { name in
                    createSet(named: name)
                }
                .presentationDetents([.medium])
            }
            .sheet(item: $renamingSet) { memorySet in
                SetNameEditor(title: String(localized: "Rename"), initialName: memorySet.name) { name in
                    memorySet.name = name
                    memorySet.updatedAt = Date()
                    try? modelContext.save()
                }
                .presentationDetents([.medium])
            }
        }
    }

    private var filteredMemorySets: [MemorySet] {
        let query = albumSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return memorySets
        }
        return memorySets.filter { memorySet in
            memorySet.name.localizedStandardContains(query)
                || memorySet.themes.contains { $0.name.localizedStandardContains(query) }
        }
    }

    private func createSet(named name: String) {
        let memorySet = MemorySet(name: name)
        let theme = MemoryTheme(setId: memorySet.id, name: String(localized: "Default"))
        theme.set = memorySet
        modelContext.insert(memorySet)
        modelContext.insert(theme)
        try? modelContext.save()
    }

    private func delete(_ memorySet: MemorySet) {
        for photo in memorySet.photos {
            ImageStore.deleteImage(named: photo.imagePath)
        }
        modelContext.delete(memorySet)
        try? modelContext.save()
    }
}

private struct MemorySetRow: View {
    let memorySet: MemorySet
    let photoCount: Int
    let themeCount: Int
    let thumbnailImagePath: String?

    var body: some View {
        HStack(spacing: 12) {
            if let thumbnailImagePath {
                MemoryPhotoView(imagePath: thumbnailImagePath) {
                    placeholderThumbnail
                }
                .scaledToFill()
                .frame(width: 52, height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                placeholderThumbnail
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(memorySet.name)
                    .font(.headline)
                    .foregroundStyle(PalaceStyle.ink)
                HStack(spacing: 12) {
                    Label(countText(photoCount, singular: "photo", plural: "photos"), systemImage: "photo")
                    Label(countText(themeCount, singular: "theme", plural: "themes"), systemImage: "tag")
                }
                .font(.subheadline)
                .foregroundStyle(PalaceStyle.mutedInk)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .background(.white.opacity(0.74), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(PalaceStyle.paperDeep.opacity(0.42), lineWidth: 1)
        }
    }

    private var placeholderThumbnail: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(PalaceStyle.sage.opacity(0.16))
            Image(systemName: "map.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(PalaceStyle.sage)
        }
        .frame(width: 52, height: 52)
    }

    private func countText(_ count: Int, singular: String, plural: String) -> String {
        "\(count) \(count == 1 ? singular : plural)"
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
                TextField("Name", text: $name)
            }
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(name.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
