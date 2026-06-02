import SwiftData
import SwiftUI

@main
struct MindPalaceApp: App {
    var body: some Scene {
        WindowGroup {
            HomeView()
                .tint(PalaceStyle.coral)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [
            MemorySet.self,
            MemoryPhoto.self,
            MemoryTheme.self,
            MemoryItem.self,
            ReviewResult.self
        ])
    }
}
