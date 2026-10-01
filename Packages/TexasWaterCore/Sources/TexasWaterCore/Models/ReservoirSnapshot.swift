import Foundation

public struct ReservoirSnapshot: Codable, Equatable, Identifiable, Sendable {
    public struct GaugeLocation: Codable, Equatable, Sendable {
        public let coordinates: [Double]
        public let type: String

        public init(coordinates: [Double], type: String) {
            self.coordinates = coordinates
            self.type = type
        }

        public var longitude: Double? { coordinates.first }
        public var latitude: Double? { coordinates.count > 1 ? coordinates[1] : nil }
    }

    public let condensedName: String
    public let shortName: String
    public let fullName: String
    public let timestamp: String
    public let floodControlLake: String?
    public let tags: [String]
    public let gaugeLocation: GaugeLocation
    public let volume: Double?
    public let elevation: Double?
    public let area: Double?
    public let percentFull: Double?
    public let conservationCapacity: Double?
    public let conservationStorage: Double?
    public let conservationPoolElevation: Double?
    public let deadPoolElevation: Double?
    public let volumeUnderConservationPoolElevation: Double?

    public var id: String { condensedName }

    public var basinTag: String? { tags.first { $0.hasPrefix("basin_") } }
    public var regionTag: String? { tags.first { $0.hasPrefix("region_") } }
    public var isWaterSupply: Bool { tags.contains("water_supply") }

    enum CodingKeys: String, CodingKey {
        case condensedName = "condensed_name"
        case shortName = "short_name"
        case fullName = "full_name"
        case timestamp
        case floodControlLake = "flood_control_lake"
        case tags
        case gaugeLocation = "gauge_location"
        case volume
        case elevation
        case area
        case percentFull = "percent_full"
        case conservationCapacity = "conservation_capacity"
        case conservationStorage = "conservation_storage"
        case conservationPoolElevation = "conservation_pool_elevation"
        case deadPoolElevation = "dead_pool_elevation"
        case volumeUnderConservationPoolElevation = "volume_under_conservation_pool_elevation"
    }

    public init(
        condensedName: String,
        shortName: String,
        fullName: String,
        timestamp: String,
        floodControlLake: String? = nil,
        tags: [String],
        gaugeLocation: GaugeLocation,
        volume: Double? = nil,
        elevation: Double? = nil,
        area: Double? = nil,
        percentFull: Double? = nil,
        conservationCapacity: Double? = nil,
        conservationStorage: Double? = nil,
        conservationPoolElevation: Double? = nil,
        deadPoolElevation: Double? = nil,
        volumeUnderConservationPoolElevation: Double? = nil
    ) {
        self.condensedName = condensedName
        self.shortName = shortName
        self.fullName = fullName
        self.timestamp = timestamp
        self.floodControlLake = floodControlLake
        self.tags = tags
        self.gaugeLocation = gaugeLocation
        self.volume = volume
        self.elevation = elevation
        self.area = area
        self.percentFull = percentFull
        self.conservationCapacity = conservationCapacity
        self.conservationStorage = conservationStorage
        self.conservationPoolElevation = conservationPoolElevation
        self.deadPoolElevation = deadPoolElevation
        self.volumeUnderConservationPoolElevation = volumeUnderConservationPoolElevation
    }
}
