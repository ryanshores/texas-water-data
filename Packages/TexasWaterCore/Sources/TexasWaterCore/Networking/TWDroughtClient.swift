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
    private let countiesURL = URL(string: "https://waterdatafortexas.org/drought/api/geometries/counties")!
    private let soilMoistureDateURL = URL(string: "https://waterdatafortexas.org/drought/api/soil-moisture/map/current-map-date")!
    private let streamflowInfoURL = URL(string: "https://waterdatafortexas.org/drought/streamflow/daily/info")!
    private let quickDRIDateURL = URL(string: "https://waterdatafortexas.org/drought/api/quick-drought-response-index/current-map-date")!
    private let eddiDateURL = URL(string: "https://waterdatafortexas.org/drought/api/evaporative-demand-drought-index/map/current-map-date")!

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

    public func fetchCountyCatalog() async throws -> [DroughtCountyCatalogEntry] {
        let topology = try JSONDecoder().decode(CountyTopology.self, from: try await data(from: countiesURL))
        return topology.geometries.compactMap { geometry in
            guard let fips = geometry.id, let county = geometry.properties.name else { return nil }
            return DroughtCountyCatalogEntry(fips: fips, county: county)
        }
        .sorted { $0.county < $1.county }
    }

    public func fetchCountyDetail(named name: String) async throws -> DroughtCountyDetail {
        async let records = fetchCounty(named: name)
        async let topologyData = data(from: countiesURL)
        let countyRecords = try await records
        let topology = try JSONDecoder().decode(CountyTopology.self, from: try await topologyData)
        let canonicalName = countyRecords.last?.county ?? "\(name.trimmingCharacters(in: .whitespacesAndNewlines)) County"
        return DroughtCountyDetail(
            county: name,
            records: countyRecords,
            boundary: topology.boundary(named: canonicalName)
        )
    }

    public func fetchHydrologyContext() async throws -> DroughtHydrologyContext {
        async let soilMoistureDate = decode(String.self, from: soilMoistureDateURL)
        async let streamflowInfo = decode(StreamflowInfo.self, from: streamflowInfoURL)
        async let quickDRIDate = decode(String.self, from: quickDRIDateURL)
        async let eddiDate = decode(String.self, from: eddiDateURL)

        let info = try await streamflowInfo
        guard let observedAt = info.time.end, Self.isISODate(observedAt) else {
            throw TexasWaterAPIError.invalidResponse
        }
        var streamflowURL = URL(string: "https://waterdatafortexas.org/drought/streamflow/daily/data")!
        streamflowURL.append(queryItems: [
            URLQueryItem(name: "start", value: observedAt),
            URLQueryItem(name: "end", value: observedAt),
        ])
        async let streamflowData = decode(StreamflowPayload.self, from: streamflowURL)

        let soilDate = try await soilMoistureDate
        let quickDate = try await quickDRIDate
        let eddiMapDate = try await eddiDate
        guard Self.isISODate(soilDate), Self.isISODate(quickDate), Self.isISODate(eddiMapDate) else {
            throw TexasWaterAPIError.invalidResponse
        }

        return DroughtHydrologyContext(
            soilMoisture: Self.rasterLayer(
                id: "soil-moisture",
                title: "Root-zone soil moisture",
                mapDate: soilDate,
                mapPath: "api/soil-moisture/map/\(soilDate)",
                description: "SMAP root-zone soil moisture, estimated for the top meter of soil. Values are volumetric water content, not a drought category.",
                sourceURL: "https://waterdatafortexas.org/drought/soil-moisture"
            ),
            streamflow: Self.streamflowSummary(
                payload: try await streamflowData,
                observedAt: observedAt,
                sourceName: info.source?.name ?? "TWDB Surface Water Resources Division"
            ),
            indices: [
                Self.rasterLayer(
                    id: "quickdri",
                    title: "QuickDRI",
                    mapDate: quickDate,
                    mapPath: "api/quick-drought-response-index/map/\(quickDate)",
                    description: "A weekly indicator for rapid-onset, or flash, drought and short-term landscape dryness.",
                    sourceURL: "https://waterdatafortexas.org/drought/quick-drought-response-index"
                ),
                Self.rasterLayer(
                    id: "eddi-1-month",
                    title: "Evaporative demand drought index",
                    mapDate: eddiMapDate,
                    mapPath: "api/evaporative-demand-drought-index/map/\(eddiMapDate)/1-month",
                    description: "One-month EDDI shows unusual atmospheric thirst; warmer drought colors indicate higher evaporative demand.",
                    sourceURL: "https://waterdatafortexas.org/drought/evaporative-demand-drought-index"
                ),
            ]
        )
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

    private func decode<Value: Decodable>(_ type: Value.Type, from url: URL) async throws -> Value {
        try JSONDecoder().decode(type, from: try await data(from: url))
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

    private static func rasterLayer(
        id: String,
        title: String,
        mapDate: String,
        mapPath: String,
        description: String,
        sourceURL: String
    ) -> DroughtRasterLayer {
        DroughtRasterLayer(
            id: id,
            title: title,
            mapDate: mapDate,
            mapURL: "https://waterdatafortexas.org/drought/\(mapPath)",
            description: description,
            sourceName: "Water Data for Texas",
            sourceURL: sourceURL
        )
    }

    private static func streamflowSummary(
        payload: StreamflowPayload,
        observedAt: String,
        sourceName: String
    ) -> StreamflowSummary {
        let values = (payload.data?.value ?? []).compactMap(\.value).filter { $0.isFinite }
        let sorted = values.sorted()
        let median: Double?
        if sorted.isEmpty {
            median = nil
        } else if sorted.count.isMultiple(of: 2) {
            median = (sorted[sorted.count / 2 - 1] + sorted[sorted.count / 2]) / 2
        } else {
            median = sorted[sorted.count / 2]
        }
        return StreamflowSummary(
            observedAt: observedAt,
            gaugeCount: values.count,
            medianPercentile: median.map { ($0 * 100).rounded() / 100 },
            belowNormalGaugeCount: values.filter { $0 < 25 }.count,
            aboveNormalGaugeCount: values.filter { $0 > 75 }.count,
            sourceName: sourceName,
            sourceURL: "https://waterdatafortexas.org/drought/streamflow-percentiles/gauges"
        )
    }

    private static func isISODate(_ value: String) -> Bool {
        value.range(of: #"^\d{4}-\d{2}-\d{2}$"#, options: .regularExpression) != nil
    }
}

private struct StreamflowInfo: Decodable {
    let time: StreamflowTime
    let source: StreamflowSource?
}

private struct StreamflowTime: Decodable {
    let end: String?
}

private struct StreamflowSource: Decodable {
    let name: String?
}

private struct StreamflowPayload: Decodable {
    let data: StreamflowValues?
}

private struct StreamflowValues: Decodable {
    let value: [LossyDouble]?
}

private struct LossyDouble: Decodable {
    let value: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            value = nil
        } else if let number = try? container.decode(Double.self) {
            value = number
        } else if let text = try? container.decode(String.self) {
            value = Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
        } else {
            value = nil
        }
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

private struct CountyTopology: Decodable {
    let transform: CountyTopologyTransform
    let arcs: [[[Double]]]
    let objects: CountyTopologyObjects

    var geometries: [CountyTopologyGeometry] {
        objects.counties.geometries
    }

    func boundary(named county: String) -> DroughtCountyBoundary? {
        guard let geometry = geometries.first(where: { $0.properties.name?.caseInsensitiveCompare(county) == .orderedSame }),
              let fips = geometry.id,
              let rings = geometry.arcs else {
            return nil
        }
        let coordinates = rings.map(joinArcs)
        guard !coordinates.isEmpty else { return nil }
        return DroughtCountyBoundary(fips: fips, county: county, coordinates: coordinates)
    }

    private func joinArcs(_ indices: [Int]) -> [[Double]] {
        var ring: [[Double]] = []
        for index in indices {
            let arcIndex = index < 0 ? -index - 1 : index
            guard arcs.indices.contains(arcIndex) else { continue }
            let decoded = decode(arcs[arcIndex])
            let oriented = index < 0 ? Array(decoded.reversed()) : decoded
            if ring.isEmpty {
                ring.append(contentsOf: oriented)
            } else {
                ring.append(contentsOf: oriented.dropFirst())
            }
        }
        return ring
    }

    private func decode(_ arc: [[Double]]) -> [[Double]] {
        var x = 0.0
        var y = 0.0
        return arc.compactMap { point in
            guard point.count > 1 else { return nil }
            x += point[0]
            y += point[1]
            return [
                x * transform.scale[0] + transform.translate[0],
                y * transform.scale[1] + transform.translate[1],
            ]
        }
    }
}

private struct CountyTopologyTransform: Decodable {
    let scale: [Double]
    let translate: [Double]
}

private struct CountyTopologyObjects: Decodable {
    let counties: CountyTopologyObject
}

private struct CountyTopologyObject: Decodable {
    let geometries: [CountyTopologyGeometry]
}

private struct CountyTopologyGeometry: Decodable {
    let id: String?
    let properties: CountyTopologyProperties
    let arcs: [[Int]]?

    enum CodingKeys: String, CodingKey {
        case id
        case properties
        case arcs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        properties = try container.decode(CountyTopologyProperties.self, forKey: .properties)
        if let polygon = try? container.decode([[Int]].self, forKey: .arcs) {
            arcs = polygon
        } else if let multiPolygon = try? container.decode([[[Int]]].self, forKey: .arcs) {
            arcs = multiPolygon.flatMap { $0 }
        } else {
            arcs = nil
        }
    }
}

private struct CountyTopologyProperties: Decodable {
    let name: String?
}
