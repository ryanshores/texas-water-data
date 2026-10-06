import Foundation
import TexasWaterCore

/// Plot negative depth so a rising water table moves upward, with an ascending domain.
struct GroundwaterChartData {
    struct Point: Identifiable {
        let date: Date
        let depth: Double
        var id: Date { date }
        var ordinate: Double { -depth }
    }

    let points: [Point]
    let domain: ClosedRange<Double>
    var change: Double? {
        guard let first = points.first, let last = points.last, first.date != last.date else { return nil }
        return first.depth - last.depth
    }

    init(readings: [GroundwaterReading]) {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.isLenient = false
        points = readings.compactMap { reading in
            guard reading.depthBelowLandSurface.isFinite,
                  let date = formatter.date(from: reading.date),
                  formatter.string(from: date) == reading.date else { return nil }
            return Point(date: date, depth: reading.depthBelowLandSurface)
        }.sorted { $0.date < $1.date }
        let minimum = points.map(\.ordinate).min() ?? -1
        let maximum = points.map(\.ordinate).max() ?? 0
        let padding = max((maximum - minimum) * 0.05, 0.5)
        domain = (minimum - padding)...(maximum + padding)
    }
}
