import Foundation
import XCTest
@testable import MindPalace

final class CSVMemoryItemImportServiceTests: XCTestCase {
    private let service = CSVMemoryItemImportService()

    func testParseBasicFrontBackCSV() throws {
        let rows = try service.parse(data: csvData("front,back\nQuestion,Answer\nTerm,Definition"))

        XCTAssertEqual(rows, [
            .init(front: "Question", back: "Answer"),
            .init(front: "Term", back: "Definition")
        ])
    }

    func testTemplateDataParsesAsValidCSV() throws {
        let rows = try service.parse(data: service.templateData())

        XCTAssertEqual(rows, [])
    }

    func testParseSwappedColumnOrder() throws {
        let rows = try service.parse(data: csvData("back,front\nAnswer,Question"))

        XCTAssertEqual(rows, [.init(front: "Question", back: "Answer")])
    }

    func testParseUTF8BOM() throws {
        var data = Data([0xEF, 0xBB, 0xBF])
        data.append(csvData("front,back\n表,裏"))

        let rows = try service.parse(data: data)

        XCTAssertEqual(rows, [.init(front: "表", back: "裏")])
    }

    func testParseShiftJIS() throws {
        let data = try XCTUnwrap("front,back\n東京,駅".data(using: .shiftJIS))

        let rows = try service.parse(data: data)

        XCTAssertEqual(rows, [.init(front: "東京", back: "駅")])
    }

    func testParseQuotedValues() throws {
        let rows = try service.parse(data: csvData(#"""
front,back
"Hello, CSV","Line 1
Line 2"
"He said ""yes""",Answer
"""#))

        XCTAssertEqual(rows, [
            .init(front: "Hello, CSV", back: "Line 1\nLine 2"),
            .init(front: "He said \"yes\"", back: "Answer")
        ])
    }

    func testParseMissingFrontHeaderThrows() {
        XCTAssertThrowsError(try service.parse(data: csvData("question,back\nQ,A"))) { error in
            XCTAssertEqual(error as? CSVMemoryItemImportService.ImportError, .missingHeader("front"))
        }
    }

    func testParseMissingBackHeaderThrows() {
        XCTAssertThrowsError(try service.parse(data: csvData("front,answer\nQ,A"))) { error in
            XCTAssertEqual(error as? CSVMemoryItemImportService.ImportError, .missingHeader("back"))
        }
    }

    func testParseEmptyFrontThrows() {
        XCTAssertThrowsError(try service.parse(data: csvData("front,back\n,A"))) { error in
            XCTAssertEqual(error as? CSVMemoryItemImportService.ImportError, .emptyFront(row: 2))
        }
    }

    func testParseMalformedQuotesThrows() {
        XCTAssertThrowsError(try service.parse(data: csvData("front,back\n\"Question,Answer"))) { error in
            XCTAssertEqual(error as? CSVMemoryItemImportService.ImportError, .malformedCSV)
        }
    }

    func testAssignDistributesRowsByPhotoOrder() throws {
        let firstPhotoId = UUID()
        let secondPhotoId = UUID()
        let rows = [
            CSVMemoryItemImportService.Row(front: "1", back: ""),
            CSVMemoryItemImportService.Row(front: "2", back: ""),
            CSVMemoryItemImportService.Row(front: "3", back: "")
        ]

        let assignments = try service.assign(
            rows: rows,
            photos: [
                .init(id: secondPhotoId, orderIndex: 1),
                .init(id: firstPhotoId, orderIndex: 0)
            ],
            itemsPerPhoto: 2
        )

        XCTAssertEqual(assignments.map(\.photoId), [firstPhotoId, firstPhotoId, secondPhotoId])
        XCTAssertEqual(assignments.map(\.positionInPhoto), [0, 1, 0])
    }

    func testAssignCapacityOverflowThrows() {
        let rows = [
            CSVMemoryItemImportService.Row(front: "1", back: ""),
            CSVMemoryItemImportService.Row(front: "2", back: ""),
            CSVMemoryItemImportService.Row(front: "3", back: "")
        ]

        XCTAssertThrowsError(
            try service.assign(
                rows: rows,
                photos: [.init(id: UUID(), orderIndex: 0)],
                itemsPerPhoto: 2
            )
        ) { error in
            XCTAssertEqual(
                error as? CSVMemoryItemImportService.ImportError,
                .capacityExceeded(rowCount: 3, capacity: 2)
            )
        }
    }

    func testAssignGridCoordinatesStayInSafeRange() throws {
        let rows = (1...12).map { CSVMemoryItemImportService.Row(front: "\($0)", back: "") }

        let assignments = try service.assign(
            rows: rows,
            photos: [.init(id: UUID(), orderIndex: 0)],
            itemsPerPhoto: 12
        )

        for assignment in assignments {
            XCTAssertGreaterThanOrEqual(assignment.x, 0.18)
            XCTAssertLessThanOrEqual(assignment.x, 0.82)
            XCTAssertGreaterThanOrEqual(assignment.y, 0.18)
            XCTAssertLessThanOrEqual(assignment.y, 0.82)
        }
    }

    func testAssignSingleItemPlacementIsCentered() throws {
        let assignments = try service.assign(
            rows: [.init(front: "Only", back: "")],
            photos: [.init(id: UUID(), orderIndex: 0)],
            itemsPerPhoto: 3
        )

        XCTAssertEqual(assignments.first?.x, 0.5)
        XCTAssertEqual(assignments.first?.y, 0.5)
    }

    private func csvData(_ text: String) -> Data {
        Data(text.utf8)
    }
}
