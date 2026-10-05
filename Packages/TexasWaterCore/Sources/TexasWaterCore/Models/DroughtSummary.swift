import Foundation

public struct DroughtSummary: Codable, Equatable, Sendable {
    public let mapDate: String
    public let previousMapDate: String?
    public let categories: [String: Double]
    public let weekOverWeek: [String: Double?]
    public let mapAreas: [DroughtMapArea]

    public init(mapDate: String, previousMapDate: String?, categories: [String: Double], weekOverWeek: [String: Double?], mapAreas: [DroughtMapArea]) {
        self.mapDate = mapDate
        self.previousMapDate = previousMapDate
        self.categories = categories
        self.weekOverWeek = weekOverWeek
        self.mapAreas = mapAreas
    }

    public var droughtCoverage: Double { categories["D0"] ?? 0 }
    public var severeOrWorseCoverage: Double { categories["D2"] ?? 0 }
}

public struct DroughtMapArea: Codable, Equatable, Sendable, Identifiable {
    public let category: String
    public let coordinates: [[[[Double]]]]

    public init(category: String, coordinates: [[[[Double]]]]) {
        self.category = category
        self.coordinates = coordinates
    }

    public var id: String { category }
}

public struct DroughtCountyRecord: Codable, Equatable, Sendable, Identifiable {
    public let mapDate: String
    public let fips: String
    public let county: String
    public let state: String
    public let categories: [String: Double]

    public var id: String { "\(fips)-\(mapDate)" }
    public var latestCategory: String {
        ["D4", "D3", "D2", "D1", "D0"].first { (categories[$0] ?? 0) > 0 } ?? "None"
    }
}
