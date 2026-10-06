import XCTest
import SwiftUI
@testable import Texas_Water
import TexasWaterCore

@MainActor
final class TexasWaterAppTests: XCTestCase {
    func testMissingGroundwaterConfigurationShowsErrorsWithoutCrashing() async {
        let directory = FileManager.default.temporaryDirectory.appending(path: "GroundwaterTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = GroundwaterDataStore(cache: DashboardCache(directory: directory), baseURL: nil)
        await store.load()
        await store.loadHistory(wellID: "missing")
        XCTAssertNotNil(store.errorMessage)
        XCTAssertNotNil(store.historyErrors["missing"])
        XCTAssertFalse(store.isLoading)
        XCTAssertTrue(store.loadingHistoryIDs.isEmpty)
    }

    func testGroundwaterChartRendersVaryingDepths() throws {
        let chart = GroundwaterChartData(readings: try readings("""
        [{"date":"2026-10-01","depthBelowLandSurface":10},
         {"date":"2026-10-05","depthBelowLandSurface":8}]
        """))
        let controller = UIHostingController(rootView: GroundwaterHistoryChart(data: chart))
        controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 220)
        controller.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: controller.view.bounds.size).image { context in
            controller.view.layer.render(in: context.cgContext)
        }
        XCTAssertEqual(image.size.width, 390)
    }
    private func readings(_ json: String) throws -> [GroundwaterReading] {
        try JSONDecoder().decode([GroundwaterReading].self, from: Data(json.utf8))
    }

    func testGroundwaterChartUsesTemporalDatesAndRisingOrdinate() throws {
        let data = GroundwaterChartData(readings: try readings("""
        [{"date":"2026-10-05","depthBelowLandSurface":8},
         {"date":"2026-10-01","depthBelowLandSurface":10},
         {"date":"invalid","depthBelowLandSurface":20}]
        """))
        XCTAssertEqual(data.points.count, 2)
        XCTAssertEqual(data.points[1].date.timeIntervalSince(data.points[0].date), 4 * 86_400)
        XCTAssertGreaterThan(data.points[1].ordinate, data.points[0].ordinate)
        XCTAssertEqual(data.change, 2)
        XCTAssertLessThan(data.domain.lowerBound, data.domain.upperBound)
        XCTAssertTrue(data.points.allSatisfy { data.domain.contains($0.ordinate) })
    }

    func testGroundwaterChartPadsEmptyAndFlatSeries() throws {
        for input in [[], try readings("""
        [{"date":"2026-10-01","depthBelowLandSurface":10},
         {"date":"2026-10-05","depthBelowLandSurface":10}]
        """), try readings("""
        [{"date":"2026-10-01","depthBelowLandSurface":10}]
        """)] {
            let chart = GroundwaterChartData(readings: input)
            XCTAssertLessThan(chart.domain.lowerBound, chart.domain.upperBound)
            XCTAssertTrue(chart.points.allSatisfy { chart.domain.contains($0.ordinate) })
        }
    }

    func testGroundwaterCacheRecoveryAndExplicitRefresh() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "GroundwaterTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = DashboardCache(directory: directory)
        let wells = try JSONDecoder().decode([GroundwaterWell].self, from: Data("""
        [{"id":"well-1","county":"Travis","aquifer":"Trinity","status":"active","latitude":30,"longitude":-98}]
        """.utf8))
        let history = try readings("""
        [{"date":"2026-10-01","depthBelowLandSurface":10}]
        """)
        let refreshedHistory = try readings("""
        [{"date":"2026-10-05","depthBelowLandSurface":8}]
        """)
        try await cache.saveGroundwaterWells(wells)
        try await cache.saveGroundwaterHistory(history, wellID: "well-1")
        var failing = true
        var calls = 0
        let store = GroundwaterDataStore(cache: cache, fetchWells: {
            calls += 1
            if failing { throw TexasWaterAPIError.invalidResponse }
            return wells
        }, fetchHistory: { _ in
            if failing { throw TexasWaterAPIError.invalidResponse }
            return refreshedHistory
        })
        await store.load()
        await store.loadHistory(wellID: "well-1")
        XCTAssertEqual(store.wells, wells)
        XCTAssertEqual(store.histories["well-1"], history)
        XCTAssertTrue(store.errorMessage?.contains("saved") == true)
        XCTAssertTrue(store.historyErrors["well-1"]?.contains("saved") == true)
        XCTAssertFalse(store.isLoading)
        XCTAssertTrue(store.loadingHistoryIDs.isEmpty)
        failing = false
        await store.refresh()
        await store.loadHistory(wellID: "well-1")
        XCTAssertEqual(calls, 2)
        XCTAssertNil(store.errorMessage)
        XCTAssertNil(store.historyErrors["well-1"])
        XCTAssertEqual(store.histories["well-1"], refreshedHistory)
        let reloadedHistory = try await cache.loadGroundwaterHistory(wellID: "well-1")
        XCTAssertEqual(reloadedHistory, refreshedHistory)
    }

    func testGroundwaterFailureWithoutCacheCanRetry() async {
        let directory = FileManager.default.temporaryDirectory.appending(path: "GroundwaterTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        var failing = true
        let store = GroundwaterDataStore(cache: DashboardCache(directory: directory), fetchWells: {
            if failing { throw TexasWaterAPIError.invalidResponse }
            return []
        }, fetchHistory: { _ in throw TexasWaterAPIError.invalidResponse })
        await store.load()
        await store.loadHistory(wellID: "missing")
        XCTAssertNotNil(store.errorMessage)
        XCTAssertNotNil(store.historyErrors["missing"])
        failing = false
        await store.refresh()
        XCTAssertNil(store.errorMessage)
    }

    func testReservoirHistoryRefreshesAfterDashboardRefreshAndOnDemand() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReservoirTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let lake = reservoir(id: "test-\(UUID())")
        let dashboard = ReservoirDashboard(generatedAt: "2026-10-06", sourceUpdatedAt: nil,
                                          statewidePercentFull: 50, reservoirs: [lake])
        var calls = 0
        let store = ReservoirDataStore(cache: DashboardCache(directory: directory), dashboardFetcher: { dashboard }, historyFetcher: { _ in
            calls += 1
            return []
        })
        await store.refresh()
        await store.loadHistory(for: lake)
        await store.loadHistory(for: lake)
        XCTAssertEqual(calls, 1)
        await store.refresh()
        await store.loadHistory(for: lake)
        XCTAssertEqual(calls, 2)
        await store.loadHistory(for: lake, force: true)
        XCTAssertEqual(calls, 3)
    }

    func testReservoirFailedRefreshPreservesSavedHistoryAndRemainsRetryable() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: "ReservoirTests-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = DashboardCache(directory: directory)
        let lake = reservoir(id: "cached-lake")
        let observation = ReservoirObservation(date: Date(), waterLevel: 10, surfaceArea: nil,
            reservoirStorage: nil, conservationStorage: nil, percentFull: 50,
            conservationCapacity: nil, deadPoolCapacity: nil)
        try await cache.saveHistory([observation], reservoirID: lake.id)
        var failing = true
        let store = ReservoirDataStore(cache: cache, historyFetcher: { _ in
            if failing { throw TexasWaterAPIError.invalidResponse }
            return [observation]
        })
        await store.loadHistory(for: lake)
        XCTAssertEqual(store.historyByReservoirID[lake.id], [observation])
        XCTAssertTrue(store.historyErrors[lake.id]?.contains("saved") == true)
        XCTAssertTrue(store.loadingHistoryIDs.isEmpty)
        failing = false
        await store.loadHistory(for: lake)
        XCTAssertNil(store.historyErrors[lake.id])
    }

    func testWaterFormattingUsesClearFallbacksAndUnits() {
        XCTAssertEqual(WaterFormatting.percent(42.26), "42.3%")
        XCTAssertEqual(WaterFormatting.percent(nil), "Not available")
        XCTAssertEqual(WaterFormatting.change(-1.26), "-1.3 pts")
        XCTAssertEqual(WaterFormatting.change(nil), "—")
        XCTAssertEqual(WaterFormatting.feet(12.346), "12.35 ft")
        XCTAssertEqual(WaterFormatting.feet(nil), "—")
    }

    func testDashboardCacheRoundTripsDashboardAndSanitizesHistoryFileName() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TexasWaterAppTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = DashboardCache(directory: directory)
        let dashboard = ReservoirDashboard(
            generatedAt: "2026-10-05T00:00:00Z",
            sourceUpdatedAt: "2026-10-05T00:00:00Z",
            statewidePercentFull: 50,
            reservoirs: [reservoir(id: "lake/travis")]
        )
        let observations = [
            ReservoirObservation(
                date: Date(timeIntervalSince1970: 1_759_622_400),
                waterLevel: 681.2,
                surfaceArea: 17_000,
                reservoirStorage: 900_000,
                conservationStorage: 880_000,
                percentFull: 88,
                conservationCapacity: 1_000_000,
                deadPoolCapacity: 10_000
            )
        ]

        try await cache.saveDashboard(dashboard)
        try await cache.saveHistory(observations, reservoirID: "lake/travis")

        let cachedDashboard = try await cache.loadDashboard()
        let cachedHistory = try await cache.loadHistory(reservoirID: "lake/travis")

        XCTAssertEqual(cachedDashboard, dashboard)
        XCTAssertEqual(cachedHistory, observations)
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.appending(path: "history-lake-travis.json").path()))
    }

    private func reservoir(id: String) -> ReservoirSummary {
        ReservoirSummary(
            id: id,
            slug: "travis",
            shortName: "Travis",
            fullName: "Lake Travis",
            observedAt: "2026-10-05T00:00:00Z",
            latitude: 30.4,
            longitude: -97.9,
            basin: "Colorado",
            region: nil,
            isWaterSupply: true,
            isFloodControl: false,
            percentFull: 88,
            elevation: 681.2,
            surfaceArea: 17_000,
            reservoirStorage: 900_000,
            conservationStorage: 880_000,
            conservationCapacity: 1_000_000,
            conservationPoolElevation: 681,
            trend: ReservoirTrend(sevenDays: -1.2)
        )
    }
}
