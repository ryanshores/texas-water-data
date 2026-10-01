import Foundation

public enum ChangeWindow: Int, CaseIterable, Codable, Sendable {
    case oneDay = 1
    case sevenDays = 7
    case thirtyDays = 30
    case oneYear = 365
}

public enum ChangeExclusionReason: String, Codable, Equatable, Sendable {
    case insufficientHistory
    case staleLatestObservation
    case capacityChanged
    case missingPercentFull
}

public struct ReservoirChange: Codable, Equatable, Sendable {
    public let window: ChangeWindow
    public let startDate: Date?
    public let endDate: Date?
    public let percentagePointChange: Double?
    public let storageChange: Double?
    public let exclusionReason: ChangeExclusionReason?

    public var isUsable: Bool { exclusionReason == nil }
}

public enum ReservoirChangeCalculator {
    public static func calculate(
        observations: [ReservoirObservation],
        window: ChangeWindow,
        now: Date? = nil,
        staleAfterDays: Int = 3,
        calendar: Calendar = utcCalendar
    ) -> ReservoirChange {
        let valid = observations.sorted { $0.date < $1.date }
        guard let latest = valid.last else {
            return excluded(window, .insufficientHistory)
        }
        guard latest.percentFull != nil else {
            return excluded(window, .missingPercentFull, endDate: latest.date)
        }

        if let now,
           let staleCutoff = calendar.date(byAdding: .day, value: -staleAfterDays, to: now),
           latest.date < staleCutoff {
            return excluded(window, .staleLatestObservation, endDate: latest.date)
        }

        guard let target = calendar.date(byAdding: .day, value: -window.rawValue, to: latest.date) else {
            return excluded(window, .insufficientHistory, endDate: latest.date)
        }

        let candidates = valid.dropLast().filter { $0.percentFull != nil }
        guard let start = candidates.min(by: {
            abs($0.date.timeIntervalSince(target)) < abs($1.date.timeIntervalSince(target))
        }), abs(start.date.timeIntervalSince(target)) <= 2 * 86_400 else {
            return excluded(window, .insufficientHistory, endDate: latest.date)
        }

        if let startCapacity = start.conservationCapacity,
           let latestCapacity = latest.conservationCapacity,
           abs(startCapacity - latestCapacity) > max(1, latestCapacity * 0.000_001) {
            return excluded(window, .capacityChanged, startDate: start.date, endDate: latest.date)
        }

        guard let startPercent = start.percentFull, let latestPercent = latest.percentFull else {
            return excluded(window, .missingPercentFull, startDate: start.date, endDate: latest.date)
        }

        let storageChange: Double?
        if let startStorage = start.conservationStorage,
           let latestStorage = latest.conservationStorage {
            storageChange = latestStorage - startStorage
        } else {
            storageChange = nil
        }

        return ReservoirChange(
            window: window,
            startDate: start.date,
            endDate: latest.date,
            percentagePointChange: latestPercent - startPercent,
            storageChange: storageChange,
            exclusionReason: nil
        )
    }

    public static var utcCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private static func excluded(
        _ window: ChangeWindow,
        _ reason: ChangeExclusionReason,
        startDate: Date? = nil,
        endDate: Date? = nil
    ) -> ReservoirChange {
        ReservoirChange(
            window: window,
            startDate: startDate,
            endDate: endDate,
            percentagePointChange: nil,
            storageChange: nil,
            exclusionReason: reason
        )
    }
}
