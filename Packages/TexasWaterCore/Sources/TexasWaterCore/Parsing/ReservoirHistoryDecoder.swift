import Foundation

public enum ReservoirHistoryDecodingError: Error, Equatable, LocalizedError {
    case missingColumns([String])
    case invalidDate(String)

    public var errorDescription: String? {
        switch self {
        case let .missingColumns(columns):
            "History CSV is missing columns: \(columns.joined(separator: ", "))."
        case let .invalidDate(value):
            "History CSV contains invalid date: \(value)."
        }
    }
}

public enum ReservoirHistoryDecoder {
    public static let requiredColumns = [
        "date",
        "water_level",
        "surface_area",
        "reservoir_storage",
        "conservation_storage",
        "percent_full",
        "conservation_capacity",
        "dead_pool_capacity"
    ]

    public static func decode(_ text: String) throws -> [ReservoirObservation] {
        let table = try CommentedCSVParser.parse(text)
        let missing = requiredColumns.filter { !table.headers.contains($0) }
        guard missing.isEmpty else {
            throw ReservoirHistoryDecodingError.missingColumns(missing)
        }

        return try table.rows.map { row in
            guard let rawDate = row["date"], let date = parseDate(rawDate) else {
                throw ReservoirHistoryDecodingError.invalidDate(row["date"] ?? "")
            }
            return ReservoirObservation(
                date: date,
                waterLevel: number(row["water_level"]),
                surfaceArea: number(row["surface_area"]),
                reservoirStorage: number(row["reservoir_storage"]),
                conservationStorage: number(row["conservation_storage"]),
                percentFull: number(row["percent_full"]),
                conservationCapacity: number(row["conservation_capacity"]),
                deadPoolCapacity: number(row["dead_pool_capacity"])
            )
        }.sorted { $0.date < $1.date }
    }

    public static func parseDate(_ value: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let parts = value.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    private static func number(_ value: String?) -> Double? {
        guard let value, !value.isEmpty else { return nil }
        return Double(value)
    }
}
