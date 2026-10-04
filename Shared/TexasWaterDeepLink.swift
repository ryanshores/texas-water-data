import Foundation

enum TexasWaterDeepLink {
    enum Destination: Equatable {
        case today
        case reservoir(id: String)
    }

    static var todayURL: URL {
        URL(string: "texaswater://today")!
    }

    static func reservoirURL(id: String) -> URL {
        var components = URLComponents()
        components.scheme = "texaswater"
        components.host = "reservoir"
        components.percentEncodedPath = "/" + id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        return components.url!
    }

    static func destination(for url: URL) -> Destination? {
        guard url.scheme == "texaswater" else { return nil }
        if url.host == "today" { return .today }
        guard url.host == "reservoir",
              let identifier = url.pathComponents.last?.removingPercentEncoding,
              !identifier.isEmpty else {
            return nil
        }
        return .reservoir(id: identifier)
    }
}
