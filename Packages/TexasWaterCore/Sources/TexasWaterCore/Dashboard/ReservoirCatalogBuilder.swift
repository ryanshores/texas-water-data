import Foundation

public enum ReservoirCatalogBuilder {
    public static func build(
        from snapshots: [String: ReservoirSnapshot],
        historySlugsByName: [String: String] = [:]
    ) -> ReservoirDashboard {
        let officialSlugs = historySlugsByName.reduce(into: [String: String]()) {
            $0[slugify($1.key)] = $1.value
        }
        let reservoirs = snapshots.values.compactMap {
            makeSummary($0, officialSlugs: officialSlugs)
        }.sorted {
            $0.shortName.localizedCaseInsensitiveCompare($1.shortName) == .orderedAscending
        }
        let storage = reservoirs.compactMap(\.conservationStorage).reduce(0, +)
        let capacity = reservoirs.compactMap(\.conservationCapacity).reduce(0, +)
        let sourceUpdatedAt = reservoirs.map(\.observedAt).max()

        return ReservoirDashboard(
            generatedAt: ISO8601DateFormatter().string(from: Date()),
            sourceUpdatedAt: sourceUpdatedAt,
            statewidePercentFull: capacity > 0 ? storage / capacity * 100 : nil,
            reservoirs: reservoirs
        )
    }

    public static func slugify(_ value: String) -> String {
        value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    public static func displayName(forTag tag: String?) -> String? {
        guard let tag else { return nil }
        let value = tag.split(separator: "_", maxSplits: 1).last.map(String.init) ?? tag
        return value.replacingOccurrences(of: "_", with: " ").capitalized
    }

    private static func makeSummary(
        _ snapshot: ReservoirSnapshot,
        officialSlugs: [String: String]
    ) -> ReservoirSummary? {
        guard let latitude = snapshot.gaugeLocation.latitude,
              let longitude = snapshot.gaugeLocation.longitude else {
            return nil
        }
        let nameKey = slugify(snapshot.shortName)
        return ReservoirSummary(
            id: snapshot.condensedName,
            slug: officialSlugs[nameKey] ?? nameKey,
            shortName: snapshot.shortName,
            fullName: snapshot.fullName,
            observedAt: snapshot.timestamp,
            latitude: latitude,
            longitude: longitude,
            basin: displayName(forTag: snapshot.basinTag),
            region: displayName(forTag: snapshot.regionTag),
            isWaterSupply: snapshot.isWaterSupply,
            isFloodControl: snapshot.floodControlLake == "Y",
            percentFull: snapshot.percentFull,
            elevation: snapshot.elevation,
            surfaceArea: snapshot.area,
            reservoirStorage: snapshot.volume,
            conservationStorage: snapshot.conservationStorage,
            conservationCapacity: snapshot.conservationCapacity,
            conservationPoolElevation: snapshot.conservationPoolElevation
        )
    }
}
