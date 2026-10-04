import Combine
import Foundation
import TexasWaterCore

@MainActor
final class DroughtDataStore: ObservableObject {
    @Published private(set) var summary: DroughtSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var countyRecords: [DroughtCountyRecord] = []
    @Published private(set) var isLoadingCounty = false

    private let apiClient: TexasWaterAPIClient?

    init() {
        apiClient = AppEnvironment.backendURL.map(TexasWaterAPIClient.init(baseURL:))
    }

    func load() async {
        guard summary == nil, !isLoading else { return }
        await refresh()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        guard let apiClient else {
            errorMessage = "Drought data requires the Texas Water API configuration."
            return
        }
        do {
            summary = try await apiClient.fetchDroughtSummary()
            errorMessage = nil
        } catch {
            errorMessage = "Drought data is unavailable right now. (error.localizedDescription)"
        }
    }

    func loadCounty(named name: String) async {
        guard let apiClient, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoadingCounty = true
        defer { isLoadingCounty = false }
        do {
            countyRecords = try await apiClient.fetchDroughtCounty(name: name)
        } catch {
            countyRecords = []
        }
    }
}
