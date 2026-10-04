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
    private let twdbClient = TWDroughtClient()

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
        do {
            if let apiClient {
                summary = try await apiClient.fetchDroughtSummary()
            } else {
                summary = try await twdbClient.fetchSummary()
            }
            errorMessage = nil
        } catch {
            do {
                summary = try await twdbClient.fetchSummary()
                errorMessage = nil
            } catch {
                errorMessage = "Drought data is unavailable right now. \(error.localizedDescription)"
            }
        }
    }

    func loadCounty(named name: String) async {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        isLoadingCounty = true
        defer { isLoadingCounty = false }
        do {
            if let apiClient {
                countyRecords = try await apiClient.fetchDroughtCounty(name: name)
            } else {
                countyRecords = try await twdbClient.fetchCounty(named: name)
            }
        } catch {
            countyRecords = (try? await twdbClient.fetchCounty(named: name)) ?? []
        }
    }
}
