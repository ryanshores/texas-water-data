import Foundation
import TexasWaterCore

actor DashboardCache {
    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        directory = SharedWaterData.cacheDirectory(fileManager: fileManager)
    }

    func loadDashboard() throws -> ReservoirDashboard {
        try decoder.decode(ReservoirDashboard.self, from: Data(contentsOf: dashboardURL))
    }

    func saveDashboard(_ dashboard: ReservoirDashboard) throws {
        try prepareDirectory()
        try encoder.encode(dashboard).write(to: dashboardURL, options: .atomic)
    }

    func loadHistory(reservoirID: String) throws -> [ReservoirObservation] {
        try decoder.decode(
            [ReservoirObservation].self,
            from: Data(contentsOf: historyURL(reservoirID: reservoirID))
        )
    }

    func saveHistory(_ observations: [ReservoirObservation], reservoirID: String) throws {
        try prepareDirectory()
        try encoder.encode(observations).write(
            to: historyURL(reservoirID: reservoirID),
            options: .atomic
        )
    }

    private var dashboardURL: URL { directory.appending(path: "dashboard.json") }

    private func historyURL(reservoirID: String) -> URL {
        let safeID = reservoirID.replacingOccurrences(
            of: "[^A-Za-z0-9_-]",
            with: "-",
            options: .regularExpression
        )
        return directory.appending(path: "history-\(safeID).json")
    }

    private func prepareDirectory() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
}
