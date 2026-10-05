import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A direct, read-only fallback for the public TWDB Drought Monitor endpoints.
///
/// The app normally uses the Texas Water API. This client preserves the drought
/// experience when a newly released API route has not yet been deployed or the
/// Worker is temporarily unavailable.
public struct TWDroughtClient: Sendable {
    private let stateURL = URL(string: "https://waterdatafortexas.org/drought/api/drought-monitor/data/state/tx")!
    private let geoURL = URL(string: "https://waterdatafortexas.org/drought/api/drought-monitor/geo")!

    public init() {}

    public func fetchSummary() async throws -> DroughtSummary {
        async let stateData = data(from: stateURL)
        async let geoData = data(from: geoURL)
        let decoder = JSONDecoder()
        let records = try decoder.decode([StateRecord].self, from: try await stateData)
        let geo = try decoder.decode(GeoResponse.self, from: try await geoData)
        guard let current = records.max(by: { $0.mapDate < $1.mapDate }) else {
            throw TexasWaterAPIError.invalidResponse
        }
        let previous = records
            .filter { $0.mapDate < current.mapDate }
            .max(by: { $0.mapDate < $1.mapDate })

        return DroughtSummary(
            mapDate: formattedDate(current.mapDate),
            previousMapDate: previous.map { formattedDate($0.mapDate) },
            categories: current.categories,
            weekOverWeek: delta(current.categories, previous?.categories),
            mapAreas: geo.geoData.features.compactMap { feature in
                guard let coordinates = feature.geometry?.coordinates else { return nil }
                return DroughtMapArea(category: feature.properties.category, coordinates: coordinates)
            }
        )
    }

    public func fetchCounty(named name: String) async throws -> [DroughtCountyRecord] {
        let slug = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        guard let url = URL(string: "https://waterdatafortexas.org/drought/api/drought-monitor/data/county/\(slug)") else {
            throw TexasWaterAPIError.invalidResponse
        }
        let records = try JSONDecoder().decode([CountyRecord].self, from: try await data(from: url))
        return records.map {
            DroughtCountyRecord(
                mapDate: formattedDate($0.validStart ?? $0.mapDate),
                fips: $0.fips,
                county: $0.county,
                state: $0.state,
                categories: $0.categories
            )
        }
    }

    private func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw TexasWaterAPIError.invalidResponse
        }
        return data
    }

    private func formattedDate(_ value: String) -> String {
        guard value.count == 8 else { return value }
        let index = value.index(value.startIndex, offsetBy: 4)
        let end = value.index(value.startIndex, offsetBy: 6)
        return "\(value[..<index])-\(value[index..<end])-\(value[end...])"
    }

    private func delta(_ current: [String: Double], _ previous: [String: Double]?) -> [String: Double?] {
        Dictionary(uniqueKeysWithValues: ["None", "D0", "D1", "D2", "D3", "D4"].map { key in
            (key, previous.map { (current[key] ?? 0) - ($0[key] ?? 0) })
        })
    }
}

private struct StateRecord: Decodable {
    let mapDate: String
    let none: Double?
    let d0: Double?
    let d1: Double?
    let d2: Double?
    let d3: Double?
    let d4: Double?

    enum CodingKeys: String, CodingKey {
        case mapDate = "MapDate"
        case none = "None"
        case d0 = "D0"
        case d1 = "D1"
        case d2 = "D2"
        case d3 = "D3"
        case d4 = "D4"
    }

    var categories: [String: Double] {
        ["None": none ?? 0, "D0": d0 ?? 0, "D1": d1 ?? 0, "D2": d2 ?? 0, "D3": d3 ?? 0, "D4": d4 ?? 0]
    }
}

private struct CountyRecord: Decodable {
    let mapDate: String
    let validStart: String?
    let fips: String
    let county: String
    let state: String
    let none: Double?
    let d0: Double?
    let d1: Double?
    let d2: Double?
    let d3: Double?
    let d4: Double?

    enum CodingKeys: String, CodingKey {
        case mapDate = "MapDate"
        case validStart = "ValidStart"
        case fips = "FIPS"
        case county = "County"
        case state = "State"
        case none = "None"
        case d0 = "D0"
        case d1 = "D1"
        case d2 = "D2"
        case d3 = "D3"
        case d4 = "D4"
    }

    var categories: [String: Double] {
        ["None": none ?? 0, "D0": d0 ?? 0, "D1": d1 ?? 0, "D2": d2 ?? 0, "D3": d3 ?? 0, "D4": d4 ?? 0]
    }
}

private struct GeoResponse: Decodable {
    let geoData: GeoData
    enum CodingKeys: String, CodingKey { case geoData = "geo_data" }
}

private struct GeoData: Decodable {
    let features: [GeoFeature]
}

private struct GeoFeature: Decodable {
    let properties: GeoProperties
    let geometry: GeoGeometry?
}

private struct GeoProperties: Decodable {
    let category: String
}

private struct GeoGeometry: Decodable {
    let coordinates: [[[[Double]]]]?
}
