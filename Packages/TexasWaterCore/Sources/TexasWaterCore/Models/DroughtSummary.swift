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

public struct DroughtCountyBoundary: Codable, Equatable, Sendable {
    public let fips: String
    public let county: String
    /// One or more exterior/interior rings, each in longitude/latitude order.
    public let coordinates: [[[Double]]]

    public init(fips: String, county: String, coordinates: [[[Double]]]) {
        self.fips = fips
        self.county = county
        self.coordinates = coordinates
    }
}

public struct DroughtCountyDetail: Codable, Equatable, Sendable {
    public let county: String
    public let records: [DroughtCountyRecord]
    public let boundary: DroughtCountyBoundary?

    public init(county: String, records: [DroughtCountyRecord], boundary: DroughtCountyBoundary?) {
        self.county = county
        self.records = records
        self.boundary = boundary
    }
}

public struct DroughtCountyCatalogEntry: Codable, Equatable, Sendable, Identifiable {
    public let fips: String
    public let county: String

    public init(fips: String, county: String) {
        self.fips = fips
        self.county = county
    }

    public var id: String { fips }
    public var queryName: String { county.replacingOccurrences(of: " County", with: "") }
}
