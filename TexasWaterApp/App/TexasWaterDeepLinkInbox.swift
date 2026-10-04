import Foundation

@MainActor
final class TexasWaterDeepLinkInbox: ObservableObject {
    static let shared = TexasWaterDeepLinkInbox()

    @Published private(set) var pendingURL: URL?

    private init() {}

    func receive(_ url: URL) {
        pendingURL = url
    }

    func takePendingURL() -> URL? {
        defer { pendingURL = nil }
        return pendingURL
    }
}
