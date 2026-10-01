import Foundation

public struct ReservoirObservation: Codable, Equatable, Sendable {
    public let date: Date
    public let waterLevel: Double?
    public let surfaceArea: Double?
    public let reservoirStorage: Double?
    public let conservationStorage: Double?
    public let percentFull: Double?
    public let conservationCapacity: Double?
    public let deadPoolCapacity: Double?

    public init(
        date: Date,
        waterLevel: Double?,
        surfaceArea: Double?,
        reservoirStorage: Double?,
        conservationStorage: Double?,
        percentFull: Double?,
        conservationCapacity: Double?,
        deadPoolCapacity: Double?
    ) {
        self.date = date
        self.waterLevel = waterLevel
        self.surfaceArea = surfaceArea
        self.reservoirStorage = reservoirStorage
        self.conservationStorage = conservationStorage
        self.percentFull = percentFull
        self.conservationCapacity = conservationCapacity
        self.deadPoolCapacity = deadPoolCapacity
    }
}
