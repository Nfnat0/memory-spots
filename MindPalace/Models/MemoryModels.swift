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
    var frontText: String
    var backText: String
    var x: Double
    var y: Double
    var orderIndex: Int
    var createdAt: Date
    var updatedAt: Date

    init(
        photoId: UUID,
        themeId: UUID,
        frontText: String,
        backText: String,
        x: Double,
        y: Double,
        orderIndex: Int
    ) {
        self.id = UUID()
        self.photoId = photoId
        self.themeId = themeId
        self.frontText = frontText
        self.backText = backText
        self.x = x
        self.y = y
        self.orderIndex = orderIndex
        self.createdAt = Date()
        self.updatedAt = Date()
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
            "覚えた"
        case .unsure:
            "微妙"
        case .forgot:
            "忘れた"
        }
    }
}
