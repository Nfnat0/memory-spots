import Foundation
import CoreXLSX

struct CSVMemoryItemImportService {
    static let templateFileName = "memory-spots-csv-template.csv"

    struct Row: Equatable {
        var front: String
        var back: String
    }

    struct PhotoReference: Equatable {
        var id: UUID
        var orderIndex: Int
    }

    struct Assignment: Equatable {
        var row: Row
        var photoId: UUID
        var positionInPhoto: Int
        var x: Double
        var y: Double
    }

    enum ImportError: LocalizedError, Equatable {
        case unreadableEncoding
        case malformedCSV
        case missingHeader(String)
        case emptyFront(row: Int)
        case noPhotos
        case invalidItemsPerPhoto
        case capacityExceeded(rowCount: Int, capacity: Int)
        case unsupportedNumbersFile

        var errorDescription: String? {
            switch self {
            case .unreadableEncoding:
                String(localized: "Could not read the CSV text.")
            case .malformedCSV:
                String(localized: "The CSV file has malformed quotes.")
            case let .missingHeader(header):
                String(localized: "The CSV file must include a \(header) column.")
            case let .emptyFront(row):
                String(localized: "Row \(row) has an empty front value.")
            case .noPhotos:
                String(localized: "Add photos before importing CSV items.")
            case .invalidItemsPerPhoto:
                String(localized: "Items per photo must be at least 1.")
            case let .capacityExceeded(rowCount, capacity):
                String(localized: "This CSV has \(rowCount) rows, but the album can place \(capacity) items with the current setting.")
            case .unsupportedNumbersFile:
                String(localized: "Numbers files cannot be read directly. Export the spreadsheet from Numbers as CSV or Excel, then import that file.")
            }
        }
    }

    func parseFile(data: Data, fileName: String) throws -> [Row] {
        switch fileExtension(in: fileName) {
        case "xlsx":
            return try parseXLSX(data: data)
        case "numbers":
            throw ImportError.unsupportedNumbersFile
        default:
            return try parse(data: data)
        }
    }

    func parse(data: Data) throws -> [Row] {
        let text = try decode(data: data)
        let records = try parseRecords(in: text)
        return try rows(from: records)
    }

    private func rows(from records: [[String]]) throws -> [Row] {
        let mapping = try columnMapping(in: records)

        var rows: [Row] = []
        for recordIndex in records.indices where recordIndex >= mapping.dataStartIndex {
            let record = records[recordIndex]
            if isEmptyRecord(record) {
                continue
            }

            let front = value(in: record, at: mapping.frontIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            let back = value(in: record, at: mapping.backIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty else {
                throw ImportError.emptyFront(row: recordIndex + 1)
            }
            rows.append(Row(front: front, back: back))
        }
        return rows
    }

    private func parseXLSX(data: Data) throws -> [Row] {
        let file = try XLSXFile(data: data)
        let sharedStrings = try file.parseSharedStrings()
        let workbooks = try file.parseWorkbooks()

        for workbook in workbooks {
            for worksheetPath in try file.parseWorksheetPathsAndNames(workbook: workbook).map(\.path) {
                let worksheet = try file.parseWorksheet(at: worksheetPath)
                let records = records(in: worksheet, sharedStrings: sharedStrings)
                guard !records.isEmpty else {
                    continue
                }
                return try rows(from: records)
            }
        }

        throw ImportError.missingHeader("front")
    }

    func templateData() -> Data {
        Data("""
        front,back

        """.utf8)
    }

    func assign(rows: [Row], photos: [PhotoReference], itemsPerPhoto: Int) throws -> [Assignment] {
        guard itemsPerPhoto > 0 else {
            throw ImportError.invalidItemsPerPhoto
        }
        guard !photos.isEmpty else {
            throw ImportError.noPhotos
        }

        let sortedPhotos = photos.sorted { $0.orderIndex < $1.orderIndex }
        let capacity = sortedPhotos.count * itemsPerPhoto
        guard rows.count <= capacity else {
            throw ImportError.capacityExceeded(rowCount: rows.count, capacity: capacity)
        }

        return rows.enumerated().map { index, row in
            let photoIndex = index / itemsPerPhoto
            let photo = sortedPhotos[photoIndex]
            let position = index % itemsPerPhoto
            let remainingRows = rows.count - photoIndex * itemsPerPhoto
            let itemsOnPhoto = min(itemsPerPhoto, remainingRows)
            let coordinate = gridCoordinate(position: position, count: itemsOnPhoto)
            return Assignment(
                row: row,
                photoId: photo.id,
                positionInPhoto: position,
                x: coordinate.x,
                y: coordinate.y
            )
        }
    }

    private func decode(data: Data) throws -> String {
        if data.starts(with: [0xEF, 0xBB, 0xBF]),
           let text = String(data: data.dropFirst(3), encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .shiftJIS) {
            return text
        }
        throw ImportError.unreadableEncoding
    }

    private func parseRecords(in text: String) throws -> [[String]] {
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var isQuoted = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if isQuoted {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        field.append("\"")
                        index = nextIndex
                    } else {
                        isQuoted = false
                    }
                } else {
                    field.append(character)
                }
            } else {
                switch character {
                case "\"":
                    if field.isEmpty {
                        isQuoted = true
                    } else {
                        throw ImportError.malformedCSV
                    }
                case ",":
                    record.append(field)
                    field = ""
                case "\n":
                    record.append(field)
                    records.append(record)
                    record = []
                    field = ""
                case "\r":
                    record.append(field)
                    records.append(record)
                    record = []
                    field = ""
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                        index = nextIndex
                    }
                default:
                    field.append(character)
                }
            }

            index = text.index(after: index)
        }

        guard !isQuoted else {
            throw ImportError.malformedCSV
        }

        if !field.isEmpty || !record.isEmpty {
            record.append(field)
            records.append(record)
        }

        return records
    }

    private func value(in record: [String], at index: Int) -> String {
        guard record.indices.contains(index) else {
            return ""
        }
        return record[index]
    }

    private func columnMapping(in records: [[String]]) throws -> (frontIndex: Int, backIndex: Int, dataStartIndex: Int) {
        guard let firstContentIndex = records.firstIndex(where: { record in
            !isEmptyRecord(record) && !isSeparatorDirective(record)
        }) else {
            throw ImportError.missingHeader("front")
        }

        let normalizedHeader = records[firstContentIndex].map { normalizeHeader($0) }
        let frontIndex = normalizedHeader.firstIndex { isFrontHeader($0) }
        let backIndex = normalizedHeader.firstIndex { isBackHeader($0) }

        if let frontIndex, let backIndex {
            return (frontIndex, backIndex, firstContentIndex + 1)
        }
        if frontIndex != nil {
            throw ImportError.missingHeader("back")
        }
        if backIndex != nil {
            throw ImportError.missingHeader("front")
        }
        if records[firstContentIndex].count >= 2 {
            return (0, 1, firstContentIndex)
        }

        throw ImportError.missingHeader("front")
    }

    private func isEmptyRecord(_ record: [String]) -> Bool {
        record.allSatisfy { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func isSeparatorDirective(_ record: [String]) -> Bool {
        record
            .joined(separator: ",")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .hasPrefix("sep=")
    }

    private func isFrontHeader(_ value: String) -> Bool {
        [
            "front",
            "fronttext",
            "question",
            "prompt",
            "term",
            "word",
            "omote",
            "表",
            "表面",
            "質問",
            "問題",
            "用語",
            "単語"
        ].contains(value)
    }

    private func isBackHeader(_ value: String) -> Bool {
        [
            "back",
            "backtext",
            "answer",
            "definition",
            "meaning",
            "ura",
            "裏",
            "裏面",
            "答え",
            "回答",
            "解答",
            "定義",
            "意味"
        ].contains(value)
    }

    private func normalizeHeader(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "_", with: "")
            .replacingOccurrences(of: "-", with: "")
    }

    private func fileExtension(in fileName: String) -> String {
        URL(fileURLWithPath: fileName).pathExtension.lowercased()
    }

    private func records(in worksheet: Worksheet, sharedStrings: SharedStrings?) -> [[String]] {
        (worksheet.data?.rows ?? []).compactMap { row in
            var valuesByColumn: [Int: String] = [:]
            var maximumColumn = 0

            for cell in row.cells {
                let columnIndex = columnIndex(for: cell.reference.column)
                maximumColumn = max(maximumColumn, columnIndex)
                valuesByColumn[columnIndex] = value(in: cell, sharedStrings: sharedStrings)
            }

            guard maximumColumn > 0 else {
                return nil
            }
            return (1...maximumColumn).map { valuesByColumn[$0] ?? "" }
        }
    }

    private func value(in cell: Cell, sharedStrings: SharedStrings?) -> String {
        if cell.type == .sharedString {
            guard let sharedStrings else {
                return ""
            }
            return cell.stringValue(sharedStrings) ?? ""
        }
        if let inlineString = cell.inlineString?.text {
            return inlineString
        }
        return cell.value ?? ""
    }

    private func columnIndex(for reference: ColumnReference) -> Int {
        reference.value.unicodeScalars.reduce(0) { result, scalar in
            let value = Int(scalar.value - ("A" as UnicodeScalar).value + 1)
            return result * 26 + value
        }
    }

    private func gridCoordinate(position: Int, count: Int) -> (x: Double, y: Double) {
        guard count > 1 else {
            return (0.5, 0.5)
        }

        let columns = Int(ceil(sqrt(Double(count))))
        let rows = Int(ceil(Double(count) / Double(columns)))
        let column = position % columns
        let row = position / columns

        return (
            coordinate(for: column, total: columns),
            coordinate(for: row, total: rows)
        )
    }

    private func coordinate(for index: Int, total: Int) -> Double {
        let minimum = 0.18
        let maximum = 0.82
        guard total > 1 else {
            return 0.5
        }
        return minimum + (maximum - minimum) * Double(index) / Double(total - 1)
    }
}
