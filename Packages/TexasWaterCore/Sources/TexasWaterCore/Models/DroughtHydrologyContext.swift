import Foundation

/// Supplemental drought indicators published by the Texas Water Development Board.
public struct DroughtHydrologyContext: Codable, Equatable, Sendable {
    public let soilMoisture: DroughtRasterLayer
    public let streamflow: StreamflowSummary
    public let indices: [DroughtRasterLayer]

    public init(
        soilMoisture: DroughtRasterLayer,
        streamflow: StreamflowSummary,
        indices: [DroughtRasterLayer]
    ) {
        self.soilMoisture = soilMoisture
        self.streamflow = streamflow
        self.indices = indices
    }
}

/// A dated, official raster map that can be rendered at a reduced resolution on-device.
public struct DroughtRasterLayer: Codable, Equatable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let mapDate: String
    public let mapURL: String
    public let description: String
    public let sourceName: String
    public let sourceURL: String

    public init(
        id: String,
        title: String,
        mapDate: String,
        mapURL: String,
        description: String,
        sourceName: String,
        sourceURL: String
    ) {
        self.id = id
        self.title = title
        self.mapDate = mapDate
        self.mapURL = mapURL
        self.description = description
        self.sourceName = sourceName
        self.sourceURL = sourceURL
    }
}

/// Current percentile conditions from TWDB's representative USGS streamgage network.
public struct StreamflowSummary: Codable, Equatable, Sendable {
    public let observedAt: String
    public let gaugeCount: Int
    public let medianPercentile: Double?
    public let belowNormalGaugeCount: Int
    public let aboveNormalGaugeCount: Int
    public let sourceName: String
    public let sourceURL: String

    public init(
        observedAt: String,
        gaugeCount: Int,
        medianPercentile: Double?,
        belowNormalGaugeCount: Int,
        aboveNormalGaugeCount: Int,
        sourceName: String,
        sourceURL: String
    ) {
        self.observedAt = observedAt
        self.gaugeCount = gaugeCount
        self.medianPercentile = medianPercentile
        self.belowNormalGaugeCount = belowNormalGaugeCount
        self.aboveNormalGaugeCount = aboveNormalGaugeCount
        self.sourceName = sourceName
        self.sourceURL = sourceURL
    }
}
