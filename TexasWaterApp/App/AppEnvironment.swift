import Foundation

enum AppEnvironment {
    static var backendURL: URL? {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "TEXAS_WATER_API_BASE_URL") as? String,
              !value.isEmpty,
              let url = URL(string: value),
              url.scheme == "https" else {
            return nil
        }
        return url
    }
}
