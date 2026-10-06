import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Direct TWDB groundwater access used when the Texas Water API cannot respond.
public struct TWDBGroundwaterClient: Sendable {
    private let load: @Sendable (URL) async throws -> Data

    public init(load: @escaping @Sendable (URL) async throws -> Data = { url in
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw TWDBClientError.nonHTTPResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw TWDBClientError.unsuccessfulStatus(response.statusCode, url)
        }
        return data
    }) {
        self.load = load
    }

    public func fetchWells() async throws -> [GroundwaterWell] {
        async let metadataData = load(TWDBEndpoint.groundwaterWells)
        async let recentData = load(TWDBEndpoint.groundwaterRecentConditions)
        let metadata = try JSONDecoder().decode(WellMetadata.self, from: await metadataData)
        let recent = try JSONDecoder().decode(RecentConditions.self, from: await recentData)
        let readings = Dictionary(recent.values.map { ($0.stateWellNumber, $0) }, uniquingKeysWith: { _, newest in newest })

        return metadata.features.compactMap { feature in
            guard let properties = feature.properties,
                  let coordinates = feature.geometry?.coordinates, coordinates.count >= 2,
                  let id = properties.wellNumber?.nonEmpty,
                  let county = properties.county?.nonEmpty,
                  let aquifer = properties.aquifer?.nonEmpty,
                  coordinates[0].isFinite, coordinates[1].isFinite else { return nil }
            let observation = readings[id]
            return GroundwaterWell(
                id: id,
                county: county,
                aquifer: aquifer,
                aquiferType: properties.aquiferType?.nonEmpty,
                status: properties.status?.nonEmpty ?? "Unknown",
                latitude: coordinates[1],
                longitude: coordinates[0],
                observedAt: observation?.date,
                depthBelowLandSurface: observation?.dailyHighWaterLevel.value
            )
        }
        .sorted { $0.county == $1.county ? $0.id < $1.id : $0.county < $1.county }
    }

    public func fetchHistory(wellID: String) async throws -> [GroundwaterReading] {
        guard wellID.range(of: #"^\d{7}$"#, options: .regularExpression) != nil else {
            throw TexasWaterAPIError.invalidResponse
        }
        let url = TWDBEndpoint.groundwaterWellHistory(id: wellID)
        let payload = try JSONDecoder().decode(WellHistory.self, from: await load(url))
        var daily: [String: (total: Double, count: Int)] = [:]
        for item in payload.values {
            guard let date = item.datetime?.prefix(10),
                  date.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil,
                  let depth = item.waterLevel.value, depth.isFinite else { continue }
            let key = String(date)
            let prior = daily[key] ?? (0, 0)
            daily[key] = (prior.total + depth, prior.count + 1)
        }
        return daily.keys.sorted().suffix(730).compactMap { date in
            guard let value = daily[date], value.count > 0 else { return nil }
            return GroundwaterReading(date: date, depthBelowLandSurface: value.total / Double(value.count))
        }
    }
}

private struct WellMetadata: Decodable {
    let features: [Feature]
    struct Feature: Decodable {
        let geometry: Geometry?
        let properties: Properties?
    }
    struct Geometry: Decodable { let coordinates: [Double]? }
    struct Properties: Decodable {
        let wellNumber: String?
        let county: String?
        let aquifer: String?
        let aquiferType: String?
        let status: String?
        enum CodingKeys: String, CodingKey {
            case wellNumber = "well_number"
            case county, aquifer, status
            case aquiferType = "aquifer_type"
        }
    }
}

private struct RecentConditions: Decodable {
    let values: [Value]
    struct Value: Decodable {
        let stateWellNumber: String
        let date: String
        let dailyHighWaterLevel: JSONNumber
        enum CodingKeys: String, CodingKey {
            case stateWellNumber = "state_well_number"
            case date
            case dailyHighWaterLevel = "daily_high_water_level(ft below land surface)"
        }
    }
}

private struct WellHistory: Decodable {
    let values: [Value]
    struct Value: Decodable {
        let datetime: String?
        let waterLevel: JSONNumber
        enum CodingKeys: String, CodingKey {
            case datetime
            case waterLevel = "water_level(ft below land surface)"
        }
    }
}

private struct JSONNumber: Decodable {
    let value: Double?
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try? container.decode(Double.self)
    }
}

private extension String {
    var nonEmpty: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
