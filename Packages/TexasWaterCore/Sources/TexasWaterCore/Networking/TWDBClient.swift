import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum TWDBEndpoint {
    public static let baseURL = URL(string: "https://waterdatafortexas.org")!
    public static let statewidePage = baseURL.appending(path: "reservoirs/statewide")
    public static let recentConditions = baseURL.appending(path: "reservoirs/recent-conditions.json")
    public static let groundwaterWells = baseURL.appending(path: "groundwater/wells.geojson")
    public static let groundwaterRecentConditions = baseURL.appending(path: "groundwater/recent-conditions.json")

    public static func groundwaterWellHistory(id: String) -> URL {
        baseURL.appending(path: "groundwater/well/\(id).json")
    }

    public static func oneYearHistory(slug: String) -> URL {
        baseURL.appending(path: "reservoirs/individual/\(slug)-1year.csv")
    }
}

public enum TWDBClientError: Error, LocalizedError {
    case nonHTTPResponse
    case unsuccessfulStatus(Int, URL)
    case invalidText(URL)

    public var errorDescription: String? {
        switch self {
        case .nonHTTPResponse:
            "TWDB returned a non-HTTP response."
        case let .unsuccessfulStatus(status, url):
            "TWDB returned HTTP \(status) for \(url.absoluteString)."
        case let .invalidText(url):
            "TWDB returned non-UTF-8 text for \(url.absoluteString)."
        }
    }
}

public struct ReservoirHistoryLink: Equatable, Sendable {
    public let name: String
    public let slug: String

    public init(name: String, slug: String) {
        self.name = name
        self.slug = slug
    }
}

public struct TWDBClient: Sendable {
    private static let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    public init() {}

    public func fetchCurrentConditions() async throws -> [String: ReservoirSnapshot] {
        let data = try await data(from: TWDBEndpoint.recentConditions)
        return try JSONDecoder().decode([String: ReservoirSnapshot].self, from: data)
    }

    public func fetchHistory(slug: String) async throws -> [ReservoirObservation] {
        let url = TWDBEndpoint.oneYearHistory(slug: slug)
        let responseData = try await data(from: url)
        guard let text = String(data: responseData, encoding: .utf8) else {
            throw TWDBClientError.invalidText(url)
        }
        return try ReservoirHistoryDecoder.decode(text)
    }

    public func fetchHistoricalSlugs() async throws -> [String] {
        try await fetchHistoricalLinks().map(\.slug)
    }

    public func fetchHistoricalLinks() async throws -> [ReservoirHistoryLink] {
        let responseData = try await data(from: TWDBEndpoint.statewidePage)
        guard let html = String(data: responseData, encoding: .utf8) else {
            throw TWDBClientError.invalidText(TWDBEndpoint.statewidePage)
        }
        return Self.extractHistoricalLinks(from: html)
    }

    public static func extractHistoricalSlugs(from html: String) -> [String] {
        Array(Set(extractHistoricalLinks(from: html).map(\.slug))).sorted()
    }

    public static func extractHistoricalLinks(from html: String) -> [ReservoirHistoryLink] {
        let pattern = #"<a\s+[^>]*href=[\"']/reservoirs/individual/([^\"'?#/]+)[\"'][^>]*>([^<]+)</a>"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(html.startIndex..., in: html)
        let links = expression.matches(in: html, range: range).compactMap { match -> ReservoirHistoryLink? in
            guard let slugRange = Range(match.range(at: 1), in: html),
                  let nameRange = Range(match.range(at: 2), in: html) else { return nil }
            return ReservoirHistoryLink(
                name: decodeHTMLEntities(String(html[nameRange])),
                slug: String(html[slugRange])
            )
        }
        return Dictionary(grouping: links, by: \.slug)
            .compactMap { $0.value.first }
            .sorted { $0.slug < $1.slug }
    }

    private func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("TexasWaterPhase0/1.0", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 45

        let retryableStatuses = Set([429, 500, 502, 503, 504])
        var lastError: Error?
        for attempt in 0..<4 {
            do {
                let (data, response) = try await Self.session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw TWDBClientError.nonHTTPResponse
                }
                if (200..<300).contains(http.statusCode) {
                    return data
                }
                let error = TWDBClientError.unsuccessfulStatus(http.statusCode, url)
                guard retryableStatuses.contains(http.statusCode), attempt < 3 else {
                    throw error
                }
                lastError = error
            } catch let error as URLError where error.code == .timedOut && attempt < 3 {
                lastError = error
            }

            let delayNanoseconds = UInt64(1 << attempt) * 1_000_000_000
            try await Task.sleep(nanoseconds: delayNanoseconds)
        }
        throw lastError ?? TWDBClientError.nonHTTPResponse
    }

    private static func decodeHTMLEntities(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}
