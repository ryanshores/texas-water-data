import Foundation
import TexasWaterCore

struct HistoryCheck: Codable, Sendable {
    let slug: String
    let observationCount: Int
    let earliestDate: Date?
    let latestDate: Date?
    let sevenDayChange: ReservoirChange?
    let error: String?
}

struct ProofReport: Codable {
    let generatedAt: Date
    let sourceURL: String
    let currentReservoirCount: Int
    let reservoirsWithPercentFull: Int
    let discoveredHistorySlugCount: Int
    let checkedHistoryCount: Int
    let successfulHistoryCount: Int
    let failedHistoryCount: Int
    let staleHistoryCount: Int
    let historyChecks: [HistoryCheck]
}

@main
enum ReservoirDataProof {
    static func main() async {
        do {
            let arguments = try Arguments.parse(CommandLine.arguments)
            let report = try await run(limit: arguments.limit)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(report)
            try data.write(to: arguments.output, options: .atomic)

            print("Phase 0 data proof complete")
            print("Current reservoirs: \(report.currentReservoirCount)")
            print("History slugs discovered: \(report.discoveredHistorySlugCount)")
            print("Histories validated: \(report.successfulHistoryCount)/\(report.checkedHistoryCount)")
            print("Failures: \(report.failedHistoryCount)")
            print("Report: \(arguments.output.path)")

            if report.failedHistoryCount > 0 {
                Foundation.exit(EXIT_FAILURE)
            }
        } catch {
            FileHandle.standardError.write(Data("reservoir-data-proof: \(error.localizedDescription)\n".utf8))
            Foundation.exit(EXIT_FAILURE)
        }
    }

    static func run(limit: Int?) async throws -> ProofReport {
        let client = TWDBClient()
        async let currentTask = client.fetchCurrentConditions()
        async let slugsTask = client.fetchHistoricalSlugs()
        let (current, discoveredSlugs) = try await (currentTask, slugsTask)
        let selectedSlugs = limit.map { Array(discoveredSlugs.prefix($0)) } ?? discoveredSlugs

        var checks: [HistoryCheck] = []
        for chunk in selectedSlugs.chunked(into: 2) {
            let chunkChecks = await withTaskGroup(of: HistoryCheck.self) { group in
                for slug in chunk {
                    group.addTask {
                        do {
                            let observations = try await client.fetchHistory(slug: slug)
                            let change = ReservoirChangeCalculator.calculate(
                                observations: observations,
                                window: .sevenDays
                            )
                            return HistoryCheck(
                                slug: slug,
                                observationCount: observations.count,
                                earliestDate: observations.first?.date,
                                latestDate: observations.last?.date,
                                sevenDayChange: change,
                                error: nil
                            )
                        } catch {
                            return HistoryCheck(
                                slug: slug,
                                observationCount: 0,
                                earliestDate: nil,
                                latestDate: nil,
                                sevenDayChange: nil,
                                error: error.localizedDescription
                            )
                        }
                    }
                }
                var results: [HistoryCheck] = []
                for await check in group { results.append(check) }
                return results
            }
            checks.append(contentsOf: chunkChecks)
            try await Task.sleep(nanoseconds: 250_000_000)
        }
        checks.sort { $0.slug < $1.slug }

        let now = Date()
        let staleCutoff = ReservoirChangeCalculator.utcCalendar.date(byAdding: .day, value: -3, to: now)!
        return ProofReport(
            generatedAt: now,
            sourceURL: TWDBEndpoint.recentConditions.absoluteString,
            currentReservoirCount: current.count,
            reservoirsWithPercentFull: current.values.filter { $0.percentFull != nil }.count,
            discoveredHistorySlugCount: discoveredSlugs.count,
            checkedHistoryCount: checks.count,
            successfulHistoryCount: checks.filter { $0.error == nil && $0.observationCount > 0 }.count,
            failedHistoryCount: checks.filter { $0.error != nil || $0.observationCount == 0 }.count,
            staleHistoryCount: checks.filter {
                $0.error == nil && $0.latestDate.map { $0 < staleCutoff } == true
            }.count,
            historyChecks: checks
        )
    }
}

private struct Arguments {
    let output: URL
    let limit: Int?

    static func parse(_ arguments: [String]) throws -> Arguments {
        var output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appending(path: "phase-0-report.json")
        var limit: Int?
        var index = 1
        while index < arguments.count {
            switch arguments[index] {
            case "--output":
                index += 1
                guard index < arguments.count else { throw ArgumentError.missingValue("--output") }
                output = URL(fileURLWithPath: arguments[index], relativeTo: URL(fileURLWithPath: FileManager.default.currentDirectoryPath)).standardizedFileURL
            case "--limit":
                index += 1
                guard index < arguments.count, let parsed = Int(arguments[index]), parsed > 0 else {
                    throw ArgumentError.invalidValue("--limit")
                }
                limit = parsed
            default:
                throw ArgumentError.unknown(arguments[index])
            }
            index += 1
        }
        return Arguments(output: output, limit: limit)
    }
}

private enum ArgumentError: Error, LocalizedError {
    case missingValue(String)
    case invalidValue(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case let .missingValue(flag): "Missing value for \(flag)."
        case let .invalidValue(flag): "Invalid value for \(flag)."
        case let .unknown(flag): "Unknown argument \(flag)."
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
