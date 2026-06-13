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

    func testParseHeaderlessTwoColumnCSV() throws {
        let rows = try service.parse(data: csvData("Tokyo,Station\nOsaka,Castle"))

        XCTAssertEqual(rows, [
            .init(front: "Tokyo", back: "Station"),
            .init(front: "Osaka", back: "Castle")
        ])
    }

    func testParseJapaneseHeaders() throws {
        let rows = try service.parse(data: csvData("質問,回答\n東京,駅"))

        XCTAssertEqual(rows, [.init(front: "東京", back: "駅")])
    }

    func testParseSkipsLeadingEmptyRowsAndSeparatorDirective() throws {
        let rows = try service.parse(data: csvData("\nsep=,\nfront,back\nQuestion,Answer"))

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

    func testParseXLSXFile() throws {
        let rows = try service.parseFile(data: xlsxData(), fileName: "items.xlsx")

        XCTAssertEqual(rows, [
            .init(front: "Question", back: "Answer"),
            .init(front: "Term", back: "Definition")
        ])
    }

    func testParseNumbersFileThrowsActionableError() {
        XCTAssertThrowsError(try service.parseFile(data: Data(), fileName: "items.numbers")) { error in
            XCTAssertEqual(error as? CSVMemoryItemImportService.ImportError, .unsupportedNumbersFile)
        }
    }

    func testParseMissingFrontHeaderThrows() {
        XCTAssertThrowsError(try service.parse(data: csvData("unknown,back\nQ,A"))) { error in
            XCTAssertEqual(error as? CSVMemoryItemImportService.ImportError, .missingHeader("front"))
        }
    }

    func testParseMissingBackHeaderThrows() {
        XCTAssertThrowsError(try service.parse(data: csvData("front,unknown\nQ,A"))) { error in
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

    private func xlsxData() throws -> Data {
        let base64 = [
            "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",
            "AA=="
        ].joined()
        return try XCTUnwrap(Data(base64Encoded: base64))
    }
}
