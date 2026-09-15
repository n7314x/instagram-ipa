import Foundation
import WebKit

enum InstagramSessionState: String, Sendable {
    case unknown
    case loggedOut
    case authenticated
}

@MainActor
final class SessionManager {
    private let dataStore = WKWebsiteDataStore.default()

    func hasInstagramCookies() async -> Bool {
        let cookies = await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { continuation.resume(returning: $0) }
        }
        return cookies.contains {
            $0.domain.lowercased().contains("instagram.com") && $0.name == "sessionid" && !$0.value.isEmpty
        }
    }
}
