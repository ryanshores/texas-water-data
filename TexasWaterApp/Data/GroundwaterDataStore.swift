import Foundation
import TexasWaterCore

@MainActor
final class GroundwaterDataStore: ObservableObject {
    @Published private(set) var wells: [GroundwaterWell] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var favoriteIDs: Set<String>
    @Published private(set) var histories: [String: [GroundwaterReading]] = [:]
    @Published private(set) var historyErrors: [String: String] = [:]
    @Published private(set) var loadingHistoryIDs: Set<String> = []

    private let fetchWells: () async throws -> [GroundwaterWell]
    private let fetchHistory: (String) async throws -> [GroundwaterReading]
    private let fetchDirectWells: () async throws -> [GroundwaterWell]
    private let fetchDirectHistory: (String) async throws -> [GroundwaterReading]
    private let cache: DashboardCache
    private let defaults: UserDefaults
    private let favoritesKey = "favoriteGroundwaterWellIDs"

    init(defaults: UserDefaults? = nil, cache: DashboardCache = DashboardCache(),
         baseURL: URL? = AppEnvironment.backendURL,
         fetchWells: (() async throws -> [GroundwaterWell])? = nil,
         fetchHistory: ((String) async throws -> [GroundwaterReading])? = nil,
         fetchDirectWells: (() async throws -> [GroundwaterWell])? = nil,
         fetchDirectHistory: ((String) async throws -> [GroundwaterReading])? = nil) {
        self.defaults = defaults ?? SharedWaterData.defaults
        favoriteIDs = Set(self.defaults.stringArray(forKey: favoritesKey) ?? [])
        self.cache = cache
        let client = baseURL.map(TexasWaterAPIClient.init(baseURL:))
        let directClient = TWDBGroundwaterClient()
        self.fetchDirectWells = fetchDirectWells ?? { try await directClient.fetchWells() }
        self.fetchDirectHistory = fetchDirectHistory ?? { id in try await directClient.fetchHistory(wellID: id) }
        let fallbackWells = self.fetchDirectWells
        let fallbackHistory = self.fetchDirectHistory
        let backendWells: (() async throws -> [GroundwaterWell])? = if let fetchWells {
            fetchWells
        } else if let client {
            { try await client.fetchGroundwaterWells() }
        } else {
            nil
        }
        let backendHistory: ((String) async throws -> [GroundwaterReading])? = if let fetchHistory {
            fetchHistory
        } else if let client {
            { id in try await client.fetchGroundwaterHistory(wellID: id) }
        } else {
            nil
        }
        self.fetchWells = {
            guard let backendWells else { return try await fallbackWells() }
            do { return try await backendWells() }
            catch { return try await fallbackWells() }
        }
        self.fetchHistory = { id in
            guard let backendHistory else { return try await fallbackHistory(id) }
            do { return try await backendHistory(id) }
            catch { return try await fallbackHistory(id) }
        }
    }

    func load() async {
        guard wells.isEmpty, !isLoading else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        if wells.isEmpty, let saved = try? await cache.loadGroundwaterWells() { wells = saved }
        do {
            wells = try await fetchWells()
            errorMessage = nil
            try? await cache.saveGroundwaterWells(wells)
        } catch {
            errorMessage = wells.isEmpty
                ? "Groundwater monitoring wells are unavailable right now. \(error.localizedDescription)"
                : "Showing saved monitoring wells because the latest refresh failed."
        }
    }

    func loadHistory(wellID: String) async {
        guard !loadingHistoryIDs.contains(wellID) else { return }
        loadingHistoryIDs.insert(wellID)
        defer { loadingHistoryIDs.remove(wellID) }
        if histories[wellID] == nil, let saved = try? await cache.loadGroundwaterHistory(wellID: wellID) {
            histories[wellID] = saved
        }
        do {
            let fresh = try await fetchHistory(wellID)
            histories[wellID] = fresh
            historyErrors[wellID] = nil
            try? await cache.saveGroundwaterHistory(fresh, wellID: wellID)
        } catch {
            historyErrors[wellID] = histories[wellID]?.isEmpty == false
                ? "Showing saved history because the latest refresh failed."
                : "Well history is unavailable right now. \(error.localizedDescription)"
        }
    }

    func toggleFavorite(_ well: GroundwaterWell) {
        if favoriteIDs.contains(well.id) { favoriteIDs.remove(well.id) } else { favoriteIDs.insert(well.id) }
        defaults.set(favoriteIDs.sorted(), forKey: favoritesKey)
    }
}
