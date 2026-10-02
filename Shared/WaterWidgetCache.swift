import Foundation
import TexasWaterCore

enum SharedWaterData {
    static let appGroupIdentifier = "group.com.ryanshores.TexasWater"
    static let favoritesKey = "favoriteReservoirIDs"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupIdentifier) ?? .standard
    }

    static func cacheDirectory(fileManager: FileManager = .default) -> URL {
        let base = fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupIdentifier)
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return base.appending(path: "TexasWater", directoryHint: .isDirectory)
    }

    static func loadDashboard(fileManager: FileManager = .default) -> ReservoirDashboard? {
        let url = cacheDirectory(fileManager: fileManager).appending(path: "dashboard.json")
        return try? JSONDecoder().decode(ReservoirDashboard.self, from: Data(contentsOf: url))
    }

    static func saveDashboard(_ dashboard: ReservoirDashboard, fileManager: FileManager = .default) {
        let directory = cacheDirectory(fileManager: fileManager)
        let url = directory.appending(path: "dashboard.json")
        do {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(dashboard).write(to: url, options: .atomic)
        } catch {
            // Widgets can still show their in-memory refresh when shared storage is unavailable.
        }
    }

    static var favoriteIDs: Set<String> {
        Set(defaults.stringArray(forKey: favoritesKey) ?? [])
    }
}
