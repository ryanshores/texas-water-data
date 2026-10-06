import Foundation

public struct GroundwaterWell: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let county: String
    public let aquifer: String
    public let aquiferType: String?
    public let status: String
    public let latitude: Double
    public let longitude: Double
    public let observedAt: String?
    public let depthBelowLandSurface: Double?

    public var sourceURL: URL? { URL(string: "https://waterdatafortexas.org/groundwater/well/\(id)") }
}

public struct GroundwaterReading: Codable, Equatable, Sendable, Identifiable {
    public let date: String
    public let depthBelowLandSurface: Double
    public var id: String { date }
}

public enum GroundwaterTrend {
    /// Positive means the water table rose. Depth below land surface decreases as water rises.
    public static func waterTableChange(readings: [GroundwaterReading]) -> Double? {
        guard let first = readings.first, let last = readings.last, first.date != last.date else { return nil }
        return first.depthBelowLandSurface - last.depthBelowLandSurface
    }
}
