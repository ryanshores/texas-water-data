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
    @Published private(set) var dashboardRevision = 0
    @Published private(set) var historyErrors: [String: String] = [:]

    private let twdbClient = TWDBClient()
    private let apiClient: TexasWaterAPIClient?
    private let cache: DashboardCache
    private let defaults: UserDefaults
    private let favoritesKey = SharedWaterData.favoritesKey
    private let dashboardFetcher: (() async throws -> ReservoirDashboard)?
    private let historyFetcher: ((ReservoirSummary) async throws -> [ReservoirObservation])?
    private var historyRevisions: [String: Int] = [:]

    init(defaults: UserDefaults? = nil, cache: DashboardCache = DashboardCache(),
         dashboardFetcher: (() async throws -> ReservoirDashboard)? = nil,
         historyFetcher: ((ReservoirSummary) async throws -> [ReservoirObservation])? = nil) {
        self.defaults = defaults ?? SharedWaterData.defaults
        favoriteIDs = Set(self.defaults.stringArray(forKey: favoritesKey) ?? [])
        apiClient = AppEnvironment.backendURL.map(TexasWaterAPIClient.init(baseURL:))
        self.dashboardFetcher = dashboardFetcher
        self.historyFetcher = historyFetcher
        self.cache = cache
    }

    var reservoirs: [ReservoirSummary] { dashboard?.reservoirs ?? [] }
    var capacityContext: ReservoirCapacityContext { dashboard?.capacityContext ?? ReservoirAnalytics.capacityContext(for: []) }
    var basinSummaries: [BasinSummary] { dashboard?.basinSummaries ?? [] }
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

    func majorOnly(_ reservoirs: [ReservoirSummary], enabled: Bool) -> [ReservoirSummary] {
        enabled ? reservoirs.filter(capacityContext.isMajor) : reservoirs
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
            var fresh: ReservoirDashboard
            if let dashboardFetcher {
                fresh = try await dashboardFetcher()
                source = .backend
            } else if let apiClient {
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
            dashboardRevision += 1
            errorMessage = nil
            try? await cache.saveDashboard(fresh)
        } catch {
            errorMessage = dashboard == nil
                ? "Texas water data is unavailable right now. \(error.localizedDescription)"
                : "Showing saved data because the latest refresh failed."
        }
    }

    func loadHistory(for reservoir: ReservoirSummary, force: Bool = false) async {
        guard !loadingHistoryIDs.contains(reservoir.id),
              force || historyRevisions[reservoir.id] != dashboardRevision else { return }
        let requestedRevision = dashboardRevision
        loadingHistoryIDs.insert(reservoir.id)
        defer { loadingHistoryIDs.remove(reservoir.id) }

        if historyByReservoirID[reservoir.id] == nil,
           let cached = try? await cache.loadHistory(reservoirID: reservoir.id) {
            historyByReservoirID[reservoir.id] = cached
        }

        do {
            let history: [ReservoirObservation]
            if let historyFetcher {
                history = try await historyFetcher(reservoir)
            } else if let apiClient {
                do {
                    let backendHistory = try await apiClient.fetchHistory(reservoirID: reservoir.id)
                    history = coversOneYear(backendHistory)
                        ? backendHistory
                        : try await twdbClient.fetchHistory(slug: reservoir.slug)
                } catch {
                    history = try await twdbClient.fetchHistory(slug: reservoir.slug)
                }
            } else {
                history = try await twdbClient.fetchHistory(slug: reservoir.slug)
            }
            historyByReservoirID[reservoir.id] = history
            historyRevisions[reservoir.id] = requestedRevision
            historyErrors[reservoir.id] = nil
            try? await cache.saveHistory(history, reservoirID: reservoir.id)
        } catch {
            historyErrors[reservoir.id] = historyByReservoirID[reservoir.id]?.isEmpty == false
                ? "Showing saved history because the latest refresh failed."
                : "History for \(reservoir.shortName) is unavailable. Pull to refresh to retry."
        }
        // A dashboard refresh can finish while this request is in flight.
        // Do not let that older request mark the newly refreshed history as current.
        if requestedRevision != dashboardRevision {
            loadingHistoryIDs.remove(reservoir.id)
            await loadHistory(for: reservoir)
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
        async let snapshots = twdbClient.fetchCurrentConditions()
        async let links = twdbClient.fetchHistoricalLinks()
        let current = try await snapshots
        let officialLinks = (try? await links) ?? []
        let slugsByName = officialLinks.reduce(into: [String: String]()) {
            $0[$1.name] = $1.slug
        }
        return ReservoirCatalogBuilder.build(from: current, historySlugsByName: slugsByName)
    }

    private func coversOneYear(_ observations: [ReservoirObservation]) -> Bool {
        guard let first = observations.min(by: { $0.date < $1.date })?.date,
              let last = observations.max(by: { $0.date < $1.date })?.date else {
            return false
        }
        return last.timeIntervalSince(first) >= 363 * 86_400
    }
}
