import Foundation
import SwiftData

@Model
final class MemorySet: Identifiable {
    var id: UUID
    var name: String
    var detail: String
    var createdAt: Date
    var updatedAt: Date

    init(name: String, detail: String = "") {
        self.id = UUID()
        self.name = name
        self.detail = detail
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class MemoryPhoto: Identifiable {
    var id: UUID
    var setId: UUID
    var title: String
    var imagePath: String
    var latitude: Double?
    var longitude: Double?
    var orderIndex: Int
    var createdAt: Date

    init(
        setId: UUID,
        title: String,
        imagePath: String,
        latitude: Double? = nil,
        longitude: Double? = nil,
        orderIndex: Int
    ) {
        self.id = UUID()
        self.setId = setId
        self.title = title
        self.imagePath = imagePath
        self.latitude = latitude
        self.longitude = longitude
        self.orderIndex = orderIndex
        self.createdAt = Date()
    }
}

@Model
final class MemoryTheme: Identifiable {
    var id: UUID
    var setId: UUID
    var name: String
    var colorName: String
    var createdAt: Date

    init(setId: UUID, name: String, colorName: String = "yellow") {
        self.id = UUID()
        self.setId = setId
        self.name = name
        self.colorName = colorName
        self.createdAt = Date()
    }
}

@Model
final class MemoryItem: Identifiable {
    var id: UUID
    var photoId: UUID
    var themeId: UUID
    var type: String = MemoryItemType.stickyText.rawValue
    var frontText: String
    var backText: String
    var colorName: String?
    var iconName: String?
    var imagePath: String?
    var rotation: Double = 0
    var scale: Double = 1
    var x: Double
    var y: Double
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        photoId: UUID,
        themeId: UUID,
        type: MemoryItemType = .stickyText,
        frontText: String,
        backText: String,
        colorName: String? = nil,
        iconName: String? = nil,
        imagePath: String? = nil,
        rotation: Double = 0,
        scale: Double = 1,
        x: Double,
        y: Double,
        orderIndex: Int
    ) {
        self.id = UUID()
        self.photoId = photoId
        self.themeId = themeId
        self.type = type.rawValue
        self.frontText = frontText
        self.backText = backText
        self.colorName = colorName
        self.iconName = iconName
        self.imagePath = imagePath
        self.rotation = rotation
        self.scale = scale
        self.x = x
        self.y = y
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

enum MemoryItemType: String, CaseIterable, Identifiable, Codable {
    case stickyText
    case image
    case icon
    case numberLabel
    case arrow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .stickyText:
            String(localized: "付箋")
        case .image:
            String(localized: "画像")
        case .icon:
            String(localized: "アイコン")
        case .numberLabel:
            String(localized: "番号")
        case .arrow:
            String(localized: "矢印")
        }
    }

    var systemImage: String {
        switch self {
        case .stickyText:
            "note.text"
        case .image:
            "photo"
        case .icon:
            "star.fill"
        case .numberLabel:
            "number.circle.fill"
        case .arrow:
            "arrow.right"
        }
    }
}

@Model
final class ReviewResult: Identifiable {
    var id: UUID
    var itemId: UUID
    var result: String
    var reviewedAt: Date

    init(itemId: UUID, result: ReviewGrade) {
        self.id = UUID()
        self.itemId = itemId
        self.result = result.rawValue
        self.reviewedAt = Date()
    }
}

enum ReviewGrade: String, CaseIterable, Identifiable {
    case remembered
    case unsure
    case forgot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .remembered:
            String(localized: "覚えた")
        case .unsure:
            String(localized: "微妙")
        case .forgot:
            String(localized: "忘れた")
        }
    }
}
