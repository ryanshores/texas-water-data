import Combine
import Foundation
import TexasWaterCore

@MainActor
final class DroughtDataStore: ObservableObject {
    enum Source: String {
        case backend = "Texas Water API"
        case direct = "Water Data for Texas"
    }

    @Published private(set) var summary: DroughtSummary?
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var countyRecords: [DroughtCountyRecord] = []
    @Published private(set) var countyDetail: DroughtCountyDetail?
    @Published private(set) var counties: [DroughtCountyCatalogEntry] = []
    @Published private(set) var isLoadingCounty = false
    @Published private(set) var source: Source = .direct

    private let apiClient: TexasWaterAPIClient?
    private let twdbClient = TWDroughtClient()

    init() {
        apiClient = AppEnvironment.backendURL.map(TexasWaterAPIClient.init(baseURL:))
    }

    func load() async {
        guard summary == nil, !isLoading else { return }
        await refresh()
        await loadCountyCatalog()
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let apiClient {
                summary = try await apiClient.fetchDroughtSummary()
                source = .backend
            } else {
                summary = try await twdbClient.fetchSummary()
                source = .direct
            }
            errorMessage = nil
        } catch {
            do {
                summary = try await twdbClient.fetchSummary()
                source = .direct
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
                let detail = try await apiClient.fetchDroughtCounty(name: name)
                countyDetail = detail
                countyRecords = detail.records
            } else {
                let records = try await twdbClient.fetchCounty(named: name)
                countyDetail = DroughtCountyDetail(county: name, records: records, boundary: nil)
                countyRecords = records
            }
        } catch {
            countyDetail = try? await twdbClient.fetchCountyDetail(named: name)
            if countyDetail != nil { source = .direct }
            if let countyDetail {
                countyRecords = countyDetail.records
            } else {
                countyRecords = []
            }
        }
    }

    private func loadCountyCatalog() async {
        guard counties.isEmpty else { return }
        if let apiClient, let catalog = try? await apiClient.fetchDroughtCountyCatalog() {
            counties = catalog
        } else {
            counties = (try? await twdbClient.fetchCountyCatalog()) ?? []
        }
    }
}
