import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func seedAWSExamSetIfNeeded(modelContext: ModelContext) {
        let localizedSetName = String(localized: "My Room & Park")
        var descriptor = FetchDescriptor<MemorySet>(
            predicate: #Predicate { $0.name == localizedSetName }
        )
        descriptor.fetchLimit = 1

        if let existingSet = try? modelContext.fetch(descriptor).first {
            updateSeedPhotoLocationsIfNeeded(memorySet: existingSet, modelContext: modelContext)
            return
        }

        do {
            try seedDefaultSet(modelContext: modelContext)
        } catch {
            assertionFailure("Failed to seed default set: \(error)")
        }
    }

    @MainActor
    private static func seedDefaultSet(modelContext: ModelContext) throws {
        let memorySet = MemorySet(
            name: String(localized: "My Room & Park"),
            detail: String(localized: "A sample memory set using familiar everyday spaces (My Room, Desk Setup, Local Park).")
        )
        let theme = MemoryTheme(
            setId: memorySet.id,
            name: String(localized: "Grocery List"),
            colorName: "yellow"
        )

        modelContext.insert(memorySet)
        modelContext.insert(theme)

        for (photoIndex, photoSeed) in photoSeeds.enumerated() {
            let imagePath = try ImageStore.saveBundledImage(
                named: photoSeed.resourceName,
                extension: "jpeg"
            )
            let photo = MemoryPhoto(
                setId: memorySet.id,
                title: String(localized: photoSeed.titleKey),
                imagePath: imagePath,
                latitude: photoSeed.latitude,
                longitude: photoSeed.longitude,
                orderIndex: photoIndex
            )
            modelContext.insert(photo)

            for (itemIndex, itemSeed) in photoSeed.items.enumerated() {
                modelContext.insert(
                    MemoryItem(
                        photoId: photo.id,
                        themeId: theme.id,
                        frontText: String(localized: itemSeed.frontKey),
                        backText: String(localized: itemSeed.backKey),
                        x: itemSeed.x,
                        y: itemSeed.y,
                        orderIndex: itemIndex
                    )
                )
            }
        }

        try modelContext.save()
    }

    @MainActor
    private static func updateSeedPhotoLocationsIfNeeded(memorySet: MemorySet, modelContext: ModelContext) {
        let setId = memorySet.id
        let descriptor = FetchDescriptor<MemoryPhoto>(
            predicate: #Predicate { $0.setId == setId }
        )
        guard let photos = try? modelContext.fetch(descriptor) else {
            return
        }

        var didUpdate = false
        for photoSeed in photoSeeds {
            let title = String(localized: photoSeed.titleKey)
            guard let photo = photos.first(where: { $0.title == title }) else {
                continue
            }
            if photo.latitude == nil || photo.longitude == nil {
                photo.latitude = photoSeed.latitude
                photo.longitude = photoSeed.longitude
                didUpdate = true
            }
        }

        if didUpdate {
            try? modelContext.save()
        }
    }
}

private struct SeedPhoto {
    let titleKey: LocalizedStringResource
    let resourceName: String
    let latitude: Double
    let longitude: Double
    let items: [SeedItem]
}

private struct SeedItem {
    let frontKey: LocalizedStringResource
    let backKey: LocalizedStringResource
    let x: Double
    let y: Double
}

private let photoSeeds: [SeedPhoto] = [
    SeedPhoto(
        titleKey: "My Room",
        resourceName: "my_room",
        latitude: 37.7749,
        longitude: -122.4194,
        items: [
            SeedItem(
                frontKey: "Milk",
                backKey: "Buy fresh milk from the grocery store.",
                x: 0.25,
                y: 0.7
            ),
            SeedItem(
                frontKey: "Apples",
                backKey: "Get 4 red organic apples.",
                x: 0.5,
                y: 0.45
            ),
            SeedItem(
                frontKey: "Bread",
                backKey: "Whole wheat bread for toast.",
                x: 0.7,
                y: 0.25
            )
        ]
    ),
    SeedPhoto(
        titleKey: "Desk Setup",
        resourceName: "desk_setup",
        latitude: 37.7752,
        longitude: -122.4198,
        items: [
            SeedItem(
                frontKey: "Coffee Beans",
                backKey: "Medium roast coffee beans.",
                x: 0.3,
                y: 0.6
            ),
            SeedItem(
                frontKey: "Notebook",
                backKey: "A5 pocket notebook for ideas.",
                x: 0.6,
                y: 0.35
            )
        ]
    ),
    SeedPhoto(
        titleKey: "Local Park",
        resourceName: "local_park",
        latitude: 37.7755,
        longitude: -122.4202,
        items: [
            SeedItem(
                frontKey: "Water Bottle",
                backKey: "Bring water bottle for hydration.",
                x: 0.25,
                y: 0.8
            ),
            SeedItem(
                frontKey: "Dog Food",
                backKey: "Pick up food for the puppy.",
                x: 0.5,
                y: 0.5
            )
        ]
    )
]
