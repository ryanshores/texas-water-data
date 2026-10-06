import Foundation
import TexasWaterCore

@MainActor
final class GroundwaterDataStore: ObservableObject {
    @Published private(set) var wells: [GroundwaterWell] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var favoriteIDs: Set<String>

    private let client: TexasWaterAPIClient?
    private let defaults: UserDefaults
    private let favoritesKey = "favoriteGroundwaterWellIDs"

    init(defaults: UserDefaults? = nil) {
        self.defaults = defaults ?? SharedWaterData.defaults
        favoriteIDs = Set(self.defaults.stringArray(forKey: favoritesKey) ?? [])
        client = AppEnvironment.backendURL.map(TexasWaterAPIClient.init(baseURL:))
    }

    func load() async {
        guard wells.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            guard let client else { throw TexasWaterAPIError.invalidResponse }
            wells = try await client.fetchGroundwaterWells()
            errorMessage = nil
        } catch { errorMessage = "Groundwater monitoring wells are unavailable right now. \(error.localizedDescription)" }
    }

    func toggleFavorite(_ well: GroundwaterWell) {
        if favoriteIDs.contains(well.id) { favoriteIDs.remove(well.id) } else { favoriteIDs.insert(well.id) }
        defaults.set(favoriteIDs.sorted(), forKey: favoritesKey)
    }
}
