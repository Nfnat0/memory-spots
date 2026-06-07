import Foundation

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
            }
        }
    }

    func parse(data: Data) throws -> [Row] {
        let text = try decode(data: data)
        let records = try parseRecords(in: text)
        guard let header = records.first else {
            throw ImportError.missingHeader("front")
        }

        let normalizedHeader = header.map { normalizeHeader($0) }
        guard let frontIndex = normalizedHeader.firstIndex(of: "front") else {
            throw ImportError.missingHeader("front")
        }
        guard let backIndex = normalizedHeader.firstIndex(of: "back") else {
            throw ImportError.missingHeader("back")
        }

        var rows: [Row] = []
        for (offset, record) in records.dropFirst().enumerated() {
            if record.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }

            let front = value(in: record, at: frontIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            let back = value(in: record, at: backIndex).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !front.isEmpty else {
                throw ImportError.emptyFront(row: offset + 2)
            }
            rows.append(Row(front: front, back: back))
        }
        return rows
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

    private func normalizeHeader(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
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
