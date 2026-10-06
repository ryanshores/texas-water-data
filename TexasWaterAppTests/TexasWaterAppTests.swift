import XCTest
@testable import Texas_Water
import TexasWaterCore

@MainActor
final class TexasWaterAppTests: XCTestCase {
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
