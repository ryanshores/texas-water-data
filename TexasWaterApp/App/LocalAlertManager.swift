import Foundation
import TexasWaterCore
import UserNotifications

@MainActor
final class LocalAlertManager: NSObject, ObservableObject {
    @Published var thresholdAlerts: Bool { didSet { savePreferences() } }
    @Published var rapidChangeAlerts: Bool { didSet { savePreferences() } }
    @Published var weeklySummary: Bool { didSet { savePreferences() } }
    @Published private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined

    private let defaults = SharedWaterData.defaults
    private let center = UNUserNotificationCenter.current()
    private let thresholdAlertsKey = "localThresholdAlerts"
    private let rapidChangeAlertsKey = "localRapidChangeAlerts"
    private let weeklySummaryKey = "localWeeklySummary"
    private let thresholdStatesKey = "localAlertThresholdStates"
    private let deliveryKeysKey = "localAlertDeliveryKeys"

    override init() {
        thresholdAlerts = defaults.object(forKey: thresholdAlertsKey) as? Bool ?? true
        rapidChangeAlerts = defaults.object(forKey: rapidChangeAlertsKey) as? Bool ?? true
        weeklySummary = defaults.object(forKey: weeklySummaryKey) as? Bool ?? false
        super.init()
        Task { await refreshAuthorizationStatus() }
    }

    var isEnabled: Bool {
        thresholdAlerts || rapidChangeAlerts || weeklySummary
    }

    func requestAuthorization() async {
        do {
            _ = try await center.requestAuthorization(options: [.alert, .badge, .sound])
        } catch {
            // The settings view communicates the resulting status without exposing platform errors.
        }
        await refreshAuthorizationStatus()
    }

    func evaluate(dashboard: ReservoirDashboard, favorites: Set<String>) async {
        guard isEnabled else { return }
        guard authorizationStatus == .authorized || authorizationStatus == .provisional else { return }

        let favoriteReservoirs = dashboard.reservoirs.filter { favorites.contains($0.id) }
        if thresholdAlerts {
            var states = thresholdStates
            for reservoir in favoriteReservoirs {
                let state = thresholdState(for: reservoir)
                let previous = states[reservoir.id]
                if previous != state, state != "normal" {
                    await schedule(
                        identifier: "threshold-\(reservoir.id)-\(dashboard.sourceUpdatedAt ?? dashboard.generatedAt)",
                        title: "\(reservoir.shortName) is \(state)",
                        body: "\(reservoir.shortName) is \(WaterFormatting.percent(reservoir.percentFull)) full.",
                        url: TexasWaterDeepLink.reservoirURL(id: reservoir.id)
                    )
                }
                states[reservoir.id] = state
            }
            defaults.set(states, forKey: thresholdStatesKey)
        }

        if rapidChangeAlerts {
            for reservoir in favoriteReservoirs {
                guard let change = reservoir.trend.sevenDays, abs(change) >= 2 else { continue }
                let key = "rapid-\(reservoir.id)-\(dashboard.observationDate)-\(change.rounded(toPlaces: 1))"
                guard claimDelivery(key) else { continue }
                await schedule(
                    identifier: key,
                    title: "\(reservoir.shortName) changed rapidly",
                    body: "\(change >= 0 ? "Up" : "Down") \(abs(change).formatted(.number.precision(.fractionLength(1)))) percentage points in seven days.",
                    url: TexasWaterDeepLink.reservoirURL(id: reservoir.id)
                )
            }
        }

        if weeklySummary, Calendar.current.component(.weekday, from: .now) == 1 {
            let key = "weekly-\(calendarWeekKey(for: .now))"
            if claimDelivery(key) {
                let highlights = favoriteReservoirs.prefix(3).map {
                    "\($0.shortName) \(WaterFormatting.percent($0.percentFull))"
                }.joined(separator: " · ")
                await schedule(
                    identifier: key,
                    title: "Your Texas Water weekly summary",
                    body: highlights.isEmpty ? "Add favorite reservoirs to receive a weekly summary." : highlights,
                    url: TexasWaterDeepLink.todayURL
                )
            }
        }
    }

    private func refreshAuthorizationStatus() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    private func schedule(identifier: String, title: String, body: String, url: URL) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["url": url.absoluteString]
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: nil))
    }

    private func savePreferences() {
        defaults.set(thresholdAlerts, forKey: thresholdAlertsKey)
        defaults.set(rapidChangeAlerts, forKey: rapidChangeAlertsKey)
        defaults.set(weeklySummary, forKey: weeklySummaryKey)
    }

    private var thresholdStates: [String: String] {
        get { defaults.dictionary(forKey: thresholdStatesKey) as? [String: String] ?? [:] }
        set { defaults.set(newValue, forKey: thresholdStatesKey) }
    }

    private func claimDelivery(_ key: String) -> Bool {
        var keys = defaults.stringArray(forKey: deliveryKeysKey) ?? []
        guard !keys.contains(key) else { return false }
        keys.append(key)
        defaults.set(Array(keys.suffix(100)), forKey: deliveryKeysKey)
        return true
    }

    private func thresholdState(for reservoir: ReservoirSummary) -> String {
        switch reservoir.status {
        case .critical: "critically low"
        case .low: "low"
        case .nearFull: "near full"
        default: "normal"
        }
    }

    private func calendarWeekKey(for date: Date) -> String {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return "\(components.yearForWeekOfYear ?? 0)-\(components.weekOfYear ?? 0)"
    }
}

private extension ReservoirDashboard {
    var observationDate: String { sourceUpdatedAt ?? String(generatedAt.prefix(10)) }
}

private extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let scale = pow(10, Double(places))
        return (self * scale).rounded() / scale
    }
}
