import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum TexasWaterAPIError: Error, LocalizedError {
    case invalidResponse
    case unsuccessfulStatus(Int)

    public var errorDescription: String? {
        switch self {
        case .invalidResponse: "The Texas Water API returned an invalid response."
        case let .unsuccessfulStatus(status): "The Texas Water API returned HTTP \(status)."
        }
    }
}

public struct TexasWaterAPIClient: Sendable {
    public let baseURL: URL

    public init(baseURL: URL) {
        self.baseURL = baseURL
    }

    public func fetchDashboard() async throws -> ReservoirDashboard {
        try await decode(path: "v1/dashboard")
    }

    public func fetchDroughtSummary() async throws -> DroughtSummary {
        try await decode(path: "v1/drought")
    }

    public func fetchDroughtHydrologyContext() async throws -> DroughtHydrologyContext {
        try await decode(path: "v1/drought/context")
    }

    public func fetchDroughtCounty(name: String) async throws -> DroughtCountyDetail {
        let encoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        return try await decode(path: "v1/drought/counties/\(encoded)")
    }

    public func fetchDroughtCountyCatalog() async throws -> [DroughtCountyCatalogEntry] {
        let payload: CountyCatalogPayload = try await decode(path: "v1/drought/counties")
        return payload.counties
    }

    public func fetchHistory(reservoirID: String, range: String = "1y") async throws -> [ReservoirObservation] {
        let encodedID = reservoirID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? reservoirID
        let payload: [HistoryPayload] = try await decode(path: "v1/reservoirs/\(encodedID)/history?range=\(range)")
        return try payload.map { item in
            guard let date = ReservoirHistoryDecoder.parseDate(item.date) else {
                throw ReservoirHistoryDecodingError.invalidDate(item.date)
            }
            return ReservoirObservation(
                date: date,
                waterLevel: item.waterLevel,
                surfaceArea: item.surfaceArea,
                reservoirStorage: item.reservoirStorage,
                conservationStorage: item.conservationStorage,
                percentFull: item.percentFull,
                conservationCapacity: item.conservationCapacity,
                deadPoolCapacity: item.deadPoolCapacity
            )
        }
    }

    private func decode<Value: Decodable & Sendable>(path: String) async throws -> Value {
        let url = URL(string: path, relativeTo: baseURL)!
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TexasWaterAPIError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw TexasWaterAPIError.unsuccessfulStatus(http.statusCode)
        }
        return try JSONDecoder().decode(Value.self, from: data)
    }

    private struct HistoryPayload: Decodable, Sendable {
        let date: String
        let waterLevel: Double?
        let surfaceArea: Double?
        let reservoirStorage: Double?
        let conservationStorage: Double?
        let percentFull: Double?
        let conservationCapacity: Double?
        let deadPoolCapacity: Double?
    }

    private struct CountyCatalogPayload: Decodable, Sendable {
        let counties: [DroughtCountyCatalogEntry]
    }
}
