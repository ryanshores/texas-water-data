import Foundation
import XCTest
@testable import TexasWaterCore

final class TexasWaterCoreTests: XCTestCase {
    func testDecodesCurrentConditionsAndTags() throws {
        let data = try fixture(named: "recent-conditions", extension: "json")
        let decoded = try JSONDecoder().decode([String: ReservoirSnapshot].self, from: data)
        let travis = try XCTUnwrap(decoded["Travis"])

        XCTAssertEqual(travis.fullName, "Lake Travis")
        XCTAssertEqual(travis.percentFull, 89.2)
        XCTAssertEqual(travis.gaugeLocation.latitude, 30.392)
        XCTAssertEqual(travis.basinTag, "basin_colorado")
        XCTAssertTrue(travis.isWaterSupply)
    }

    func testDecodesCommentedHistoryAndMissingValues() throws {
        let data = try fixture(named: "travis-history", extension: "csv")
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let observations = try ReservoirHistoryDecoder.decode(text)

        XCTAssertEqual(observations.count, 3)
        XCTAssertEqual(observations.last?.percentFull, 89.2)
        XCTAssertEqual(observations.last?.conservationStorage, 979_476)
    }

    func testCalculatesSevenDayChangeUsingNearestObservation() throws {
        let data = try fixture(named: "travis-history", extension: "csv")
        let text = try XCTUnwrap(String(data: data, encoding: .utf8))
        let observations = try ReservoirHistoryDecoder.decode(text)
        let change = ReservoirChangeCalculator.calculate(observations: observations, window: .sevenDays)

        XCTAssertTrue(change.isUsable)
        XCTAssertEqual(change.percentagePointChange ?? 0, -1.1, accuracy: 0.000_001)
        XCTAssertEqual(change.storageChange, -11_634)
    }

    func testExcludesChangeWhenCapacityWasRevised() {
        let start = observation(date: "2026-09-24", percent: 50, capacity: 1_000)
        let end = observation(date: "2026-10-01", percent: 51, capacity: 1_100)
        let change = ReservoirChangeCalculator.calculate(observations: [start, end], window: .sevenDays)

        XCTAssertEqual(change.exclusionReason, .capacityChanged)
        XCTAssertNil(change.percentagePointChange)
    }

    func testExtractsUniqueHistorySlugsFromStatewideHTML() {
        let html = """
        <a href="/reservoirs/individual/travis">Travis</a>
        <a href="/reservoirs/individual/travis">Travis again</a>
        <a href="/reservoirs/individual/buchanan">Buchanan</a>
        <a href="/reservoirs/individual/lake-o-the-pines">Lake O&#39; the Pines</a>
        """
        XCTAssertEqual(
            TWDBClient.extractHistoricalSlugs(from: html),
            ["buchanan", "lake-o-the-pines", "travis"]
        )
        XCTAssertEqual(
            TWDBClient.extractHistoricalLinks(from: html).first { $0.slug == "lake-o-the-pines" }?.name,
            "Lake O' the Pines"
        )
    }

    func testBuildsDashboardAndClassifiesReservoirs() throws {
        let data = try fixture(named: "recent-conditions", extension: "json")
        let decoded = try JSONDecoder().decode([String: ReservoirSnapshot].self, from: data)
        let dashboard = ReservoirCatalogBuilder.build(from: decoded)
        let travis = try XCTUnwrap(dashboard.reservoirs.first)

        XCTAssertEqual(dashboard.statewidePercentFull ?? 0, 89.2, accuracy: 0.01)
        XCTAssertEqual(travis.slug, "travis")
        XCTAssertEqual(travis.status, .normal)
        XCTAssertEqual(travis.heightFromConservationPool ?? 0, -6.48, accuracy: 0.001)
    }

    func testDashboardUsesOfficialHistorySlugMapping() throws {
        let data = try fixture(named: "recent-conditions", extension: "json")
        let decoded = try JSONDecoder().decode([String: ReservoirSnapshot].self, from: data)
        let dashboard = ReservoirCatalogBuilder.build(
            from: decoded,
            historySlugsByName: ["Travis": "official-travis-slug"]
        )

        XCTAssertEqual(dashboard.reservoirs.first?.slug, "official-travis-slug")
    }

    func testStatusThresholds() {
        XCTAssertEqual(ReservoirStatus.classify(percentFull: 100), .nearFull)
        XCTAssertEqual(ReservoirStatus.classify(percentFull: 95), .nearFull)
        XCTAssertEqual(ReservoirStatus.classify(percentFull: 25), .normal)
        XCTAssertEqual(ReservoirStatus.classify(percentFull: 24.9), .low)
        XCTAssertEqual(ReservoirStatus.classify(percentFull: 9.9), .critical)
        XCTAssertEqual(ReservoirStatus.classify(percentFull: nil), .unavailable)
    }

    func testCapacityContextAndBasinSummariesUsePairedValues() {
        let small = summary(id: "small", basin: "Colorado", storage: 10, capacity: 100)
        let medium = summary(id: "medium", basin: "Colorado", storage: 200, capacity: 400)
        let large = summary(id: "large", basin: "Brazos", storage: 900, capacity: 1_000)
        let incomplete = summary(id: "incomplete", basin: "Brazos", storage: nil, capacity: 2_000)
        let reservoirs = [small, medium, large, incomplete]

        let context = ReservoirAnalytics.capacityContext(for: reservoirs)
        let basins = ReservoirAnalytics.basinSummaries(for: reservoirs)

        XCTAssertEqual(context.tier(for: small), .small)
        XCTAssertEqual(context.tier(for: large), .large)
        XCTAssertTrue(context.isMajor(large))
        XCTAssertEqual(context.statewideShare(for: large) ?? 0, 1000 / 3500 * 100, accuracy: 0.001)
        guard let brazos = basins.first(where: { $0.name == "Brazos" }) else {
            return XCTFail("Expected a Brazos basin summary")
        }
        XCTAssertEqual(brazos.percentFull ?? 0, 90, accuracy: 0.001)
        XCTAssertEqual(brazos.includedReservoirCount, 1)
    }

    private func fixture(named name: String, extension fileExtension: String) throws -> Data {
        let url = try XCTUnwrap(
            Bundle.module.url(forResource: name, withExtension: fileExtension, subdirectory: "Fixtures")
        )
        return try Data(contentsOf: url)
    }

    private func observation(date: String, percent: Double, capacity: Double) -> ReservoirObservation {
        ReservoirObservation(
            date: ReservoirHistoryDecoder.parseDate(date)!,
            waterLevel: nil,
            surfaceArea: nil,
            reservoirStorage: nil,
            conservationStorage: percent * 10,
            percentFull: percent,
            conservationCapacity: capacity,
            deadPoolCapacity: nil
        )
    }

    private func summary(id: String, basin: String, storage: Double?, capacity: Double?) -> ReservoirSummary {
        ReservoirSummary(
            id: id, slug: id, shortName: id, fullName: id, observedAt: "2026-10-02",
            latitude: 30, longitude: -97, basin: basin, region: nil,
            isWaterSupply: true, isFloodControl: false,
            percentFull: storage.flatMap { value in capacity.map { value / $0 * 100 } },
            elevation: nil, surfaceArea: nil, reservoirStorage: nil,
            conservationStorage: storage, conservationCapacity: capacity,
            conservationPoolElevation: nil
        )
    }
}
