import Foundation
import SwiftData

enum SeedDataService {
    @MainActor
    static func seedAWSExamSetIfNeeded(modelContext: ModelContext) {
        do {
            try seedSetIfNeeded(defaultStudySeed, sortIndex: 0, modelContext: modelContext)
        } catch {
            assertionFailure("Failed to seed default set: \(error)")
        }
    }

    @MainActor
    static func seedAppStoreScreenshotSetsIfNeeded(modelContext: ModelContext) {
        do {
            for (index, seed) in appStoreScreenshotSeeds.enumerated() {
                try seedSetIfNeeded(seed, sortIndex: appStoreScreenshotSeeds.count - index, modelContext: modelContext)
            }
        } catch {
            assertionFailure("Failed to seed App Store screenshot sets: \(error)")
        }
    }

    @MainActor
    private static func seedSetIfNeeded(_ seed: SeedSet, sortIndex: Int, modelContext: ModelContext) throws {
        let stableId = seed.stableId
        var descriptor = FetchDescriptor<MemorySet>(
            predicate: #Predicate { $0.stableId == stableId }
        )
        descriptor.fetchLimit = 1

        if (try? modelContext.fetch(descriptor).first) != nil {
            return
        }

        let seedDate = Date(timeIntervalSinceReferenceDate: 802_000_000 + Double(sortIndex * 600))
        let memorySet = MemorySet(name: seed.name, detail: seed.detail, stableId: seed.stableId)
        memorySet.createdAt = seedDate
        memorySet.updatedAt = seedDate
        modelContext.insert(memorySet)

        var themesByName: [String: MemoryTheme] = [:]
        for (themeIndex, themeSeed) in seed.themes.enumerated() {
            let theme = MemoryTheme(
                setId: memorySet.id,
                name: themeSeed.name,
                colorName: themeSeed.colorName
            )
            theme.createdAt = seedDate.addingTimeInterval(Double(themeIndex))
            theme.set = memorySet
            themesByName[themeSeed.name] = theme
            modelContext.insert(theme)
        }

        for (photoIndex, photoSeed) in seed.photos.enumerated() {
            let imagePath = try ImageStore.saveBundledImage(
                named: photoSeed.resourceName,
                extension: photoSeed.fileExtension
            )
            let photo = MemoryPhoto(
                setId: memorySet.id,
                title: photoSeed.title,
                imagePath: imagePath,
                latitude: photoSeed.latitude,
                longitude: photoSeed.longitude,
                orderIndex: photoIndex
            )
            photo.createdAt = seedDate.addingTimeInterval(Double(photoIndex * 60))
            photo.set = memorySet
            modelContext.insert(photo)

            for (itemIndex, itemSeed) in photoSeed.items.enumerated() {
                guard let theme = themesByName[itemSeed.themeName] else {
                    continue
                }
                let item = MemoryItem(
                    photoId: photo.id,
                    themeId: theme.id,
                    type: itemSeed.type,
                    frontText: itemSeed.frontText,
                    backText: itemSeed.backText,
                    colorName: itemSeed.colorName,
                    iconName: itemSeed.iconName,
                    rotation: itemSeed.rotation,
                    scale: itemSeed.scale,
                    x: itemSeed.x,
                    y: itemSeed.y,
                    orderIndex: itemIndex
                )
                item.photo = photo
                item.theme = theme
                modelContext.insert(item)
            }
        }

        try modelContext.save()
    }
}

private struct SeedSet {
    let stableId: String
    let name: String
    let detail: String
    let themes: [SeedTheme]
    let photos: [SeedPhoto]
}

private struct SeedTheme {
    let name: String
    let colorName: String
}

private struct SeedPhoto {
    let title: String
    let resourceName: String
    let fileExtension: String
    let latitude: Double
    let longitude: Double
    let items: [SeedItem]
}

private struct SeedItem {
    let themeName: String
    let type: MemoryItemType
    let frontText: String
    let backText: String
    let colorName: String?
    let iconName: String?
    let rotation: Double
    let scale: Double
    let x: Double
    let y: Double

    init(
        themeName: String,
        type: MemoryItemType = .stickyText,
        frontText: String,
        backText: String,
        colorName: String? = "yellow",
        iconName: String? = nil,
        rotation: Double = 0,
        scale: Double = 1,
        x: Double,
        y: Double
    ) {
        self.themeName = themeName
        self.type = type
        self.frontText = frontText
        self.backText = backText
        self.colorName = colorName
        self.iconName = iconName
        self.rotation = rotation
        self.scale = scale
        self.x = x
        self.y = y
    }
}

private let defaultStudySeed = SeedSet(
    stableId: "default-seed-set",
    name: "Cloud Architect Exam Palace",
    detail: "A sample certification route for anchoring cloud architecture concepts to city landmarks.",
    themes: [
        SeedTheme(name: "SAA-C03 Review", colorName: "blue")
    ],
    photos: [
        SeedPhoto(
            title: "Street Wires",
            resourceName: "1B6FC3FC-ABF2-41E1-B439-C616D29DD6A5 2",
            fileExtension: "png",
            latitude: 35.6257,
            longitude: 139.7218,
            items: [
                SeedItem(
                    themeName: "SAA-C03 Review",
                    frontText: "VPC",
                    backText: "A VPC isolates network resources with subnets, route tables, and gateways.",
                    colorName: "blue",
                    x: 0.46,
                    y: 0.38
                ),
                SeedItem(
                    themeName: "SAA-C03 Review",
                    frontText: "NAT",
                    backText: "NAT lets private subnet instances reach the internet without inbound exposure.",
                    colorName: "green",
                    x: 0.63,
                    y: 0.58
                ),
                SeedItem(
                    themeName: "SAA-C03 Review",
                    frontText: "security group",
                    backText: "Stateful instance firewall: return traffic is allowed automatically.",
                    colorName: "yellow",
                    rotation: -5,
                    x: 0.35,
                    y: 0.67
                )
            ]
        ),
        SeedPhoto(
            title: "Lucky Cat Alley",
            resourceName: "7BD59672-C2DB-4B17-BBEF-9FAE24FEBEC5 2",
            fileExtension: "png",
            latitude: 35.6260,
            longitude: 139.7222,
            items: [
                SeedItem(
                    themeName: "SAA-C03 Review",
                    frontText: "IAM role",
                    backText: "Prefer roles for temporary credentials assigned to services.",
                    colorName: "yellow",
                    x: 0.48,
                    y: 0.52
                ),
                SeedItem(
                    themeName: "SAA-C03 Review",
                    type: .icon,
                    frontText: "Route 53",
                    backText: "DNS plus routing policies for latency, failover, weighted, and geolocation.",
                    colorName: nil,
                    iconName: "network",
                    x: 0.74,
                    y: 0.34
                )
            ]
        ),
        SeedPhoto(
            title: "Crosswalk Signal",
            resourceName: "FEC8D736-6AB6-46A2-8727-EFEC90FF6C83",
            fileExtension: "jpeg",
            latitude: 35.6263,
            longitude: 139.7226,
            items: [
                SeedItem(
                    themeName: "SAA-C03 Review",
                    frontText: "RTO / RPO",
                    backText: "RTO is downtime target; RPO is acceptable data loss window.",
                    colorName: "pink",
                    x: 0.42,
                    y: 0.42
                ),
                SeedItem(
                    themeName: "SAA-C03 Review",
                    frontText: "CloudFront",
                    backText: "Edge cache static and dynamic content close to viewers.",
                    colorName: "blue",
                    x: 0.63,
                    y: 0.67
                )
            ]
        )
    ]
)

private let appStoreScreenshotSeeds: [SeedSet] = [
    SeedSet(
        stableId: "app-store-spanish-grammar-palace",
        name: "My Spanish Grammar Palace",
        detail: "A personal route for turning everyday rooms into Spanish grammar anchors.",
        themes: [
            SeedTheme(name: "Spanish Grammar", colorName: "yellow"),
            SeedTheme(name: "Vocab Recall", colorName: "green"),
            SeedTheme(name: "Speaking", colorName: "blue")
        ],
        photos: [
            SeedPhoto(
                title: "Daruma Room",
                resourceName: "1C16E944-A18E-4A3B-9651-B639C91F7F65",
                fileExtension: "png",
                latitude: 35.6264,
                longitude: 139.7228,
                items: [
                    SeedItem(
                        themeName: "Spanish Grammar",
                        frontText: "ser vs estar",
                        backText: "Ser is permanent identity; estar is temporary state or location.",
                        colorName: "yellow",
                        x: 0.50,
                        y: 0.56
                    ),
                    SeedItem(
                        themeName: "Spanish Grammar",
                        frontText: "gender endings",
                        backText: "Most -o nouns are masculine; most -a nouns are feminine.",
                        colorName: "blue",
                        rotation: -4,
                        x: 0.31,
                        y: 0.38
                    ),
                    SeedItem(
                        themeName: "Vocab Recall",
                        type: .icon,
                        frontText: "house",
                        backText: "la casa",
                        colorName: nil,
                        iconName: "house.fill",
                        x: 0.68,
                        y: 0.31
                    )
                ]
            ),
            SeedPhoto(
                title: "Duck Sofa",
                resourceName: "606BAB1B-066D-4124-8E8B-45A5A9332613",
                fileExtension: "png",
                latitude: 35.6267,
                longitude: 139.7231,
                items: [
                    SeedItem(
                        themeName: "Spanish Grammar",
                        frontText: "subjunctive",
                        backText: "Use subjunctive after doubt, desire, emotion, denial, and impersonal expressions.",
                        colorName: "green",
                        x: 0.43,
                        y: 0.47
                    ),
                    SeedItem(
                        themeName: "Spanish Grammar",
                        type: .numberLabel,
                        frontText: "1",
                        backText: "Trigger phrase: espero que...",
                        colorName: nil,
                        x: 0.22,
                        y: 0.62
                    ),
                    SeedItem(
                        themeName: "Speaking",
                        frontText: "opinion opener",
                        backText: "Use 'Desde mi punto de vista...' to start a spoken answer.",
                        colorName: "pink",
                        x: 0.68,
                        y: 0.42
                    )
                ]
            ),
            SeedPhoto(
                title: "Balloon Bedroom",
                resourceName: "52C18C29-DED8-4449-ABD8-AB3122BC148F",
                fileExtension: "png",
                latitude: 35.6270,
                longitude: 139.7234,
                items: [
                    SeedItem(
                        themeName: "Spanish Grammar",
                        frontText: "preterite",
                        backText: "Preterite is a completed action with a clear edge in time.",
                        colorName: "pink",
                        x: 0.58,
                        y: 0.36
                    ),
                    SeedItem(
                        themeName: "Spanish Grammar",
                        frontText: "object pronouns",
                        backText: "Direct object pronouns answer what; indirect answer to whom.",
                        colorName: "yellow",
                        rotation: 5,
                        x: 0.37,
                        y: 0.59
                    )
                ]
            )
        ]
    ),
    SeedSet(
        stableId: "app-store-cloud-architect-palace",
        name: "Cloud Architect Exam Palace",
        detail: "Certification notes placed along a city route with memorable landmarks.",
        themes: [
            SeedTheme(name: "SAA-C03 Review", colorName: "blue")
        ],
        photos: [
            SeedPhoto(
                title: "Street Wires",
                resourceName: "1B6FC3FC-ABF2-41E1-B439-C616D29DD6A5 2",
                fileExtension: "png",
                latitude: 35.6257,
                longitude: 139.7218,
                items: [
                    SeedItem(
                        themeName: "SAA-C03 Review",
                        frontText: "VPC",
                        backText: "A VPC isolates network resources with subnets, route tables, and gateways.",
                        colorName: "blue",
                        x: 0.46,
                        y: 0.38
                    ),
                    SeedItem(
                        themeName: "SAA-C03 Review",
                    frontText: "NAT",
                    backText: "NAT lets private subnet instances reach the internet without inbound exposure.",
                    colorName: "green",
                    x: 0.63,
                    y: 0.58
                ),
                SeedItem(
                    themeName: "SAA-C03 Review",
                    frontText: "security group",
                    backText: "Stateful instance firewall: return traffic is allowed automatically.",
                    colorName: "yellow",
                    rotation: -5,
                    x: 0.35,
                    y: 0.67
                )
            ]
        ),
            SeedPhoto(
                title: "Lucky Cat Alley",
                resourceName: "7BD59672-C2DB-4B17-BBEF-9FAE24FEBEC5 2",
                fileExtension: "png",
                latitude: 35.6260,
                longitude: 139.7222,
                items: [
                    SeedItem(
                        themeName: "SAA-C03 Review",
                        frontText: "IAM role",
                        backText: "Prefer roles for temporary credentials assigned to services.",
                        colorName: "yellow",
                        x: 0.48,
                        y: 0.52
                    ),
                    SeedItem(
                        themeName: "SAA-C03 Review",
                        type: .icon,
                        frontText: "Route 53",
                        backText: "DNS plus routing policies for latency, failover, weighted, and geolocation.",
                        colorName: nil,
                        iconName: "network",
                        x: 0.74,
                        y: 0.34
                    )
                ]
            ),
            SeedPhoto(
                title: "Crosswalk Signal",
                resourceName: "FEC8D736-6AB6-46A2-8727-EFEC90FF6C83",
                fileExtension: "jpeg",
                latitude: 35.6263,
                longitude: 139.7226,
                items: [
                    SeedItem(
                        themeName: "SAA-C03 Review",
                        frontText: "RTO / RPO",
                        backText: "RTO is downtime target; RPO is acceptable data loss window.",
                        colorName: "pink",
                        x: 0.42,
                        y: 0.42
                    ),
                    SeedItem(
                        themeName: "SAA-C03 Review",
                        frontText: "CloudFront",
                        backText: "Edge cache static and dynamic content close to viewers.",
                        colorName: "blue",
                        x: 0.63,
                        y: 0.67
                    )
                ]
            )
        ]
    ),
    SeedSet(
        stableId: "app-store-data-science-palace",
        name: "Data Science Finals Palace",
        detail: "Statistics and machine learning concepts anchored to public landmarks.",
        themes: [
            SeedTheme(name: "ML Finals", colorName: "green")
        ],
        photos: [
            SeedPhoto(
                title: "Elephant Plaza",
                resourceName: "240C63AE-B4CF-4BE2-90BE-D450878B809F",
                fileExtension: "png",
                latitude: 35.6248,
                longitude: 139.7240,
                items: [
                    SeedItem(
                        themeName: "ML Finals",
                        frontText: "overfitting",
                        backText: "Low training error and high validation error means the model memorized noise.",
                        colorName: "green",
                        x: 0.47,
                        y: 0.41
                    ),
                    SeedItem(
                        themeName: "ML Finals",
                        frontText: "regularize",
                        backText: "Add a penalty, simplify the model, or use more data.",
                        colorName: "yellow",
                        x: 0.68,
                        y: 0.60
                    )
                ]
            ),
            SeedPhoto(
                title: "Beach Ball Street",
                resourceName: "48609C36-D97F-4E8B-8A78-A6FF79942300 2",
                fileExtension: "png",
                latitude: 35.6251,
                longitude: 139.7244,
                items: [
                    SeedItem(
                        themeName: "ML Finals",
                        frontText: "p-value",
                        backText: "Probability of data this extreme if the null hypothesis were true.",
                        colorName: "blue",
                        x: 0.52,
                        y: 0.39
                    ),
                    SeedItem(
                        themeName: "ML Finals",
                        frontText: "95% CI",
                        backText: "A repeated-sampling interval that captures the true parameter 95% of the time.",
                        colorName: "pink",
                        x: 0.38,
                        y: 0.67
                    )
                ]
            ),
            SeedPhoto(
                title: "Elephant Entrance",
                resourceName: "C3D46A91-BC5E-498F-A172-A5B06D777101",
                fileExtension: "png",
                latitude: 35.6254,
                longitude: 139.7248,
                items: [
                    SeedItem(
                        themeName: "ML Finals",
                        frontText: "ROC AUC",
                        backText: "Area under the curve summarizes ranking quality across thresholds.",
                        colorName: "yellow",
                        x: 0.51,
                        y: 0.48
                    )
                ]
            )
        ]
    ),
    SeedSet(
        stableId: "app-store-medical-board-palace",
        name: "Medical Board Review Palace",
        detail: "High-yield physiology and pharmacology notes placed on tactile scenes.",
        themes: [
            SeedTheme(name: "Board Review", colorName: "pink")
        ],
        photos: [
            SeedPhoto(
                title: "Apple Table",
                resourceName: "B836C280-90F3-4FB8-AF21-6813FAEDE7E1",
                fileExtension: "png",
                latitude: 35.6238,
                longitude: 139.7257,
                items: [
                    SeedItem(
                        themeName: "Board Review",
                        frontText: "glycolysis",
                        backText: "Glucose becomes pyruvate; net yield is 2 ATP and 2 NADH.",
                        colorName: "pink",
                        x: 0.47,
                        y: 0.54
                    ),
                    SeedItem(
                        themeName: "Board Review",
                        frontText: "ADH",
                        backText: "ADH increases water reabsorption through V2 receptors.",
                        colorName: "blue",
                        x: 0.69,
                        y: 0.36
                    )
                ]
            ),
            SeedPhoto(
                title: "Indoor Bicycle",
                resourceName: "4B9A5510-F192-4488-9974-4095B63BC0D2",
                fileExtension: "png",
                latitude: 35.6241,
                longitude: 139.7261,
                items: [
                    SeedItem(
                        themeName: "Board Review",
                        frontText: "cardiac output",
                        backText: "Cardiac output equals stroke volume times heart rate.",
                        colorName: "yellow",
                        x: 0.45,
                        y: 0.45
                    ),
                    SeedItem(
                        themeName: "Board Review",
                        frontText: "beta blockers",
                        backText: "Lower heart rate, contractility, and renin release.",
                        colorName: "green",
                        x: 0.63,
                        y: 0.63
                    )
                ]
            ),
            SeedPhoto(
                title: "Penguin Table",
                resourceName: "D86AE38B-B228-4285-BD94-6AF2FCD1C71E 2",
                fileExtension: "png",
                latitude: 35.6244,
                longitude: 139.7265,
                items: [
                    SeedItem(
                        themeName: "Board Review",
                        frontText: "RAAS",
                        backText: "Renin leads to angiotensin II and aldosterone to raise pressure and volume.",
                        colorName: "yellow",
                        x: 0.47,
                        y: 0.42
                    )
                ]
            )
        ]
    )
]
