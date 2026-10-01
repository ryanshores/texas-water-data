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
        """
        XCTAssertEqual(TWDBClient.extractHistoricalSlugs(from: html), ["buchanan", "travis"])
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
}
