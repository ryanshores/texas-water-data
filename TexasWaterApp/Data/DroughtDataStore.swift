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
    @Published private(set) var hydrologyContext: DroughtHydrologyContext?
    @Published private(set) var isLoadingHydrologyContext = false
    @Published private(set) var summarySource: Source = .direct
    @Published private(set) var countySource: Source?
    @Published private(set) var hydrologyContextSource: Source?
    @Published private(set) var hydrologyContextErrorMessage: String?

    var source: Source { summarySource }

    private let apiClient: TexasWaterAPIClient?
    private let twdbClient = TWDroughtClient()
    private var isLoadingCountyCatalog = false

    init() {
        apiClient = AppEnvironment.backendURL.map(TexasWaterAPIClient.init(baseURL:))
    }

    func loadOverview() async {
        guard summary == nil else { return }
        await refresh()
    }

    func load() async {
        await loadOverview()
        async let hydrology: Void = loadHydrologyContext()
        if counties.isEmpty {
            await loadCountyCatalog()
        }
        await hydrology
    }

    func refresh() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            if let apiClient {
                summary = try await apiClient.fetchDroughtSummary()
                summarySource = .backend
            } else {
                summary = try await twdbClient.fetchSummary()
                summarySource = .direct
            }
            errorMessage = nil
        } catch {
            do {
                summary = try await twdbClient.fetchSummary()
                summarySource = .direct
                errorMessage = nil
            } catch {
                errorMessage = "Drought data is unavailable right now. \(error.localizedDescription)"
            }
        }
    }

    func loadHydrologyContext() async {
        guard hydrologyContext == nil else { return }
        await refreshHydrologyContext()
    }

    func refreshHydrologyContext() async {
        guard !isLoadingHydrologyContext else { return }
        isLoadingHydrologyContext = true
        defer { isLoadingHydrologyContext = false }
        do {
            if let apiClient {
                hydrologyContext = try await apiClient.fetchDroughtHydrologyContext()
                hydrologyContextSource = .backend
            } else {
                hydrologyContext = try await twdbClient.fetchHydrologyContext()
                hydrologyContextSource = .direct
            }
            hydrologyContextErrorMessage = nil
        } catch {
            do {
                hydrologyContext = try await twdbClient.fetchHydrologyContext()
                hydrologyContextSource = .direct
                hydrologyContextErrorMessage = nil
            } catch {
                hydrologyContextErrorMessage = "Drought context is unavailable right now. \(error.localizedDescription)"
            }
        }
    }

    func refreshAll() async {
        async let overview: Void = refresh()
        async let hydrology: Void = refreshHydrologyContext()
        await overview
        await hydrology
        if counties.isEmpty {
            await loadCountyCatalog()
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
                    countySource = .backend
                } else if let directDetail = try? await twdbClient.fetchCountyDetail(named: name) {
                    countyDetail = directDetail
                    countyRecords = directDetail.records
                    countySource = .direct
                } else {
                    countyDetail = detail
                    countyRecords = detail.records
                    countySource = .backend
                }
            } else {
                let detail = try await twdbClient.fetchCountyDetail(named: name)
                countyDetail = detail
                countyRecords = detail.records
                countySource = .direct
            }
        } catch {
            countyDetail = try? await twdbClient.fetchCountyDetail(named: name)
            if countyDetail != nil { countySource = .direct }
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
