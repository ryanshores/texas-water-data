import Foundation

public enum ReservoirStatus: String, Codable, CaseIterable, Sendable {
    case nearFull
    case normal
    case low
    case critical
    case unavailable

    public static func classify(percentFull: Double?) -> ReservoirStatus {
        guard let percentFull else { return .unavailable }
        switch percentFull {
        case 95...: return .nearFull
        case ..<10: return .critical
        case ..<25: return .low
        default: return .normal
        }
    }
}

public struct ReservoirTrend: Codable, Equatable, Sendable {
    public let oneDay: Double?
    public let sevenDays: Double?
    public let thirtyDays: Double?
    public let oneYear: Double?
    public let storageSevenDays: Double?

    public init(
        oneDay: Double? = nil,
        sevenDays: Double? = nil,
        thirtyDays: Double? = nil,
        oneYear: Double? = nil,
        storageSevenDays: Double? = nil
    ) {
        self.oneDay = oneDay
        self.sevenDays = sevenDays
        self.thirtyDays = thirtyDays
        self.oneYear = oneYear
        self.storageSevenDays = storageSevenDays
    }
}

public struct ReservoirSummary: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let slug: String
    public let shortName: String
    public let fullName: String
    public let observedAt: String
    public let latitude: Double
    public let longitude: Double
    public let basin: String?
    public let region: String?
    public let isWaterSupply: Bool
    public let isFloodControl: Bool
    public let percentFull: Double?
    public let elevation: Double?
    public let surfaceArea: Double?
    public let reservoirStorage: Double?
    public let conservationStorage: Double?
    public let conservationCapacity: Double?
    public let conservationPoolElevation: Double?
    public let trend: ReservoirTrend

    public var status: ReservoirStatus { .classify(percentFull: percentFull) }

    public var heightFromConservationPool: Double? {
        guard let elevation, let conservationPoolElevation else { return nil }
        return elevation - conservationPoolElevation
    }

    public init(
        id: String,
        slug: String,
        shortName: String,
        fullName: String,
        observedAt: String,
        latitude: Double,
        longitude: Double,
        basin: String?,
        region: String?,
        isWaterSupply: Bool,
        isFloodControl: Bool,
        percentFull: Double?,
        elevation: Double?,
        surfaceArea: Double?,
        reservoirStorage: Double?,
        conservationStorage: Double?,
        conservationCapacity: Double?,
        conservationPoolElevation: Double?,
        trend: ReservoirTrend = ReservoirTrend()
    ) {
        self.id = id
        self.slug = slug
        self.shortName = shortName
        self.fullName = fullName
        self.observedAt = observedAt
        self.latitude = latitude
        self.longitude = longitude
        self.basin = basin
        self.region = region
        self.isWaterSupply = isWaterSupply
        self.isFloodControl = isFloodControl
        self.percentFull = percentFull
        self.elevation = elevation
        self.surfaceArea = surfaceArea
        self.reservoirStorage = reservoirStorage
        self.conservationStorage = conservationStorage
        self.conservationCapacity = conservationCapacity
        self.conservationPoolElevation = conservationPoolElevation
        self.trend = trend
    }
}

public struct ReservoirDashboard: Codable, Equatable, Sendable {
    public let generatedAt: String
    public let sourceUpdatedAt: String?
    public let statewidePercentFull: Double?
    public let reservoirs: [ReservoirSummary]

    public init(
        generatedAt: String,
        sourceUpdatedAt: String?,
        statewidePercentFull: Double?,
        reservoirs: [ReservoirSummary]
    ) {
        self.generatedAt = generatedAt
        self.sourceUpdatedAt = sourceUpdatedAt
        self.statewidePercentFull = statewidePercentFull
        self.reservoirs = reservoirs
    }
}
