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
    private var isLoadingCountyCatalog = false

    init() {
        apiClient = AppEnvironment.backendURL.map(TexasWaterAPIClient.init(baseURL:))
    }

    func load() async {
        if summary == nil {
            await refresh()
        }
        if counties.isEmpty {
            await loadCountyCatalog()
        }
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
                if let boundary = detail.boundary {
                    countyDetail = DroughtCountyDetail(county: detail.county, records: detail.records, boundary: boundary)
                    countyRecords = detail.records
                    source = .backend
                } else if let directDetail = try? await twdbClient.fetchCountyDetail(named: name) {
                    countyDetail = directDetail
                    countyRecords = directDetail.records
                    source = .direct
                } else {
                    countyDetail = detail
                    countyRecords = detail.records
                    source = .backend
                }
            } else {
                let detail = try await twdbClient.fetchCountyDetail(named: name)
                countyDetail = detail
                countyRecords = detail.records
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
        guard counties.isEmpty, !isLoadingCountyCatalog else { return }
        isLoadingCountyCatalog = true
        defer { isLoadingCountyCatalog = false }
        if let apiClient, let catalog = try? await apiClient.fetchDroughtCountyCatalog() {
            counties = catalog
        } else {
            counties = (try? await twdbClient.fetchCountyCatalog()) ?? []
        }
    }
}
