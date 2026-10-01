import Combine
import Foundation
import TexasWaterCore

@MainActor
final class ReservoirDataStore: ObservableObject {
    enum Source: String {
        case backend = "Texas Water API"
        case direct = "Water Data for Texas"
        case cache = "Offline cache"
    }

    @Published private(set) var dashboard: ReservoirDashboard?
    @Published private(set) var historyByReservoirID: [String: [ReservoirObservation]] = [:]
    @Published private(set) var loadingHistoryIDs: Set<String> = []
    @Published private(set) var source: Source = .cache
    @Published private(set) var isLoading = false
    @Published private(set) var isRefreshing = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var favoriteIDs: Set<String>

    private let twdbClient = TWDBClient()
    private let apiClient: TexasWaterAPIClient?
    private let cache = DashboardCache()
    private let defaults: UserDefaults
    private let favoritesKey = "favoriteReservoirIDs"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        favoriteIDs = Set(defaults.stringArray(forKey: favoritesKey) ?? [])
        apiClient = AppEnvironment.backendURL.map(TexasWaterAPIClient.init(baseURL:))
    }

    var reservoirs: [ReservoirSummary] { dashboard?.reservoirs ?? [] }
    var favorites: [ReservoirSummary] { reservoirs.filter { favoriteIDs.contains($0.id) } }
    var hasTrendData: Bool { reservoirs.contains { $0.trend.sevenDays != nil } }

    var rising: [ReservoirSummary] {
        reservoirs
            .filter { $0.trend.sevenDays.map { $0 > 0 } == true }
            .sorted { ($0.trend.sevenDays ?? 0) > ($1.trend.sevenDays ?? 0) }
    }

    var falling: [ReservoirSummary] {
        reservoirs
            .filter { $0.trend.sevenDays.map { $0 < 0 } == true }
            .sorted { ($0.trend.sevenDays ?? 0) < ($1.trend.sevenDays ?? 0) }
    }

    var low: [ReservoirSummary] {
        reservoirs
            .filter { $0.status == .low || $0.status == .critical }
            .sorted { ($0.percentFull ?? .greatestFiniteMagnitude) < ($1.percentFull ?? .greatestFiniteMagnitude) }
    }

    var nearFull: [ReservoirSummary] {
        reservoirs
            .filter { $0.status == .nearFull }
            .sorted { ($0.percentFull ?? 0) > ($1.percentFull ?? 0) }
    }

    func load() async {
        guard dashboard == nil, !isLoading else { return }
        isLoading = true
        if let cached = try? await cache.loadDashboard() {
            dashboard = cached
            source = .cache
        }
        isLoading = false
        await refresh()
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let fresh: ReservoirDashboard
            if let apiClient {
                do {
                    fresh = try await apiClient.fetchDashboard()
                    guard !fresh.reservoirs.isEmpty else {
                        throw TexasWaterAPIError.invalidResponse
                    }
                    source = .backend
                } catch {
                    fresh = try await directDashboard()
                    source = .direct
                }
            } else {
                fresh = try await directDashboard()
                source = .direct
            }
            dashboard = fresh
            errorMessage = nil
            try? await cache.saveDashboard(fresh)
        } catch {
            errorMessage = dashboard == nil
                ? "Texas water data is unavailable right now. \(error.localizedDescription)"
                : "Showing saved data because the latest refresh failed."
        }
    }

    func loadHistory(for reservoir: ReservoirSummary) async {
        guard historyByReservoirID[reservoir.id] == nil,
              !loadingHistoryIDs.contains(reservoir.id) else { return }
        loadingHistoryIDs.insert(reservoir.id)
        defer { loadingHistoryIDs.remove(reservoir.id) }

        if let cached = try? await cache.loadHistory(reservoirID: reservoir.id) {
            historyByReservoirID[reservoir.id] = cached
        }

        do {
            let history: [ReservoirObservation]
            if let apiClient {
                do {
                    let backendHistory = try await apiClient.fetchHistory(reservoirID: reservoir.id)
                    history = backendHistory.isEmpty
                        ? try await twdbClient.fetchHistory(slug: reservoir.slug)
                        : backendHistory
                } catch {
                    history = try await twdbClient.fetchHistory(slug: reservoir.slug)
                }
            } else {
                history = try await twdbClient.fetchHistory(slug: reservoir.slug)
            }
            historyByReservoirID[reservoir.id] = history
            try? await cache.saveHistory(history, reservoirID: reservoir.id)
        } catch {
            if historyByReservoirID[reservoir.id] == nil {
                errorMessage = "History for \(reservoir.shortName) is unavailable."
            }
        }
    }

    func isFavorite(_ reservoir: ReservoirSummary) -> Bool {
        favoriteIDs.contains(reservoir.id)
    }

    func toggleFavorite(_ reservoir: ReservoirSummary) {
        if favoriteIDs.contains(reservoir.id) {
            favoriteIDs.remove(reservoir.id)
        } else {
            favoriteIDs.insert(reservoir.id)
        }
        defaults.set(Array(favoriteIDs).sorted(), forKey: favoritesKey)
    }

    private func directDashboard() async throws -> ReservoirDashboard {
        ReservoirCatalogBuilder.build(from: try await twdbClient.fetchCurrentConditions())
    }
}
