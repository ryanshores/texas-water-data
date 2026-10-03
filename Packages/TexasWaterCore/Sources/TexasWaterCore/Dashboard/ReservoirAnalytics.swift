import Foundation

public enum ReservoirCapacityTier: String, Sendable {
    case small = "Small"
    case medium = "Medium"
    case large = "Large"
    case unavailable = "Unknown"
}

public struct ReservoirCapacityContext: Sendable {
    public let statewideCapacity: Double
    public let smallThreshold: Double?
    public let majorThreshold: Double?

    public func tier(for reservoir: ReservoirSummary) -> ReservoirCapacityTier {
        guard let capacity = reservoir.conservationCapacity,
              let smallThreshold, let majorThreshold else { return .unavailable }
        if capacity <= smallThreshold { return .small }
        if capacity >= majorThreshold { return .large }
        return .medium
    }

    public func statewideShare(for reservoir: ReservoirSummary) -> Double? {
        guard let capacity = reservoir.conservationCapacity, statewideCapacity > 0 else { return nil }
        return capacity / statewideCapacity * 100
    }

    public func isMajor(_ reservoir: ReservoirSummary) -> Bool {
        guard let capacity = reservoir.conservationCapacity, let majorThreshold else { return false }
        return capacity >= majorThreshold
    }
}

public struct BasinSummary: Identifiable, Sendable {
    public let name: String
    public let reservoirs: [ReservoirSummary]
    public let conservationStorage: Double
    public let conservationCapacity: Double
    public let includedReservoirCount: Int
    public let sourceUpdatedAt: String?

    public var id: String { name }
    public var percentFull: Double? {
        conservationCapacity > 0 ? conservationStorage / conservationCapacity * 100 : nil
    }
}

public enum ReservoirAnalytics {
    public static func capacityContext(for reservoirs: [ReservoirSummary]) -> ReservoirCapacityContext {
        let capacities = reservoirs.compactMap(\.conservationCapacity).sorted()
        guard !capacities.isEmpty else {
            return ReservoirCapacityContext(statewideCapacity: 0, smallThreshold: nil, majorThreshold: nil)
        }
        return ReservoirCapacityContext(
            statewideCapacity: capacities.reduce(0, +),
            smallThreshold: lowerQuartileThreshold(capacities),
            majorThreshold: upperQuartileThreshold(capacities)
        )
    }

    public static func basinSummaries(for reservoirs: [ReservoirSummary]) -> [BasinSummary] {
        Dictionary(grouping: reservoirs, by: { $0.basin ?? "Unassigned" })
            .map { name, reservoirs in
                let paired = reservoirs.compactMap { reservoir -> (Double, Double)? in
                    guard let storage = reservoir.conservationStorage,
                          let capacity = reservoir.conservationCapacity else { return nil }
                    return (storage, capacity)
                }
                return BasinSummary(
                    name: name,
                    reservoirs: reservoirs.sorted { ($0.conservationCapacity ?? 0) > ($1.conservationCapacity ?? 0) },
                    conservationStorage: paired.reduce(0) { $0 + $1.0 },
                    conservationCapacity: paired.reduce(0) { $0 + $1.1 },
                    includedReservoirCount: paired.count,
                    sourceUpdatedAt: reservoirs.map(\.observedAt).max()
                )
            }
            .sorted { $0.conservationCapacity > $1.conservationCapacity }
    }

    private static func lowerQuartileThreshold(_ values: [Double]) -> Double {
        let memberCount = max(1, Int((Double(values.count) * 0.25).rounded(.up)))
        return values[memberCount - 1]
    }

    private static func upperQuartileThreshold(_ values: [Double]) -> Double {
        let memberCount = max(1, Int((Double(values.count) * 0.25).rounded(.up)))
        return values[values.count - memberCount]
    }
}

public extension ReservoirDashboard {
    var capacityContext: ReservoirCapacityContext { ReservoirAnalytics.capacityContext(for: reservoirs) }
    var basinSummaries: [BasinSummary] { ReservoirAnalytics.basinSummaries(for: reservoirs) }
}
