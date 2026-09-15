import Foundation
import WebKit

enum InstagramSessionState: String, Sendable {
    case unknown
    case loggedOut
    case authenticated
}

struct InstagramLaunchDecision: Equatable, Sendable {
    let sessionState: InstagramSessionState
    let initialHomeURL: URL
}

enum InstagramSessionRouting {
    static let homeURL = URL(string: "https://www.instagram.com/")!
    static let loginURL = URL(string: "https://www.instagram.com/accounts/login/")!

    static func launchDecision(hasSessionCookie: Bool) -> InstagramLaunchDecision {
        if hasSessionCookie {
            return InstagramLaunchDecision(
                sessionState: .authenticated,
                initialHomeURL: homeURL
            )
        }
        return InstagramLaunchDecision(
            sessionState: .loggedOut,
            initialHomeURL: loginURL
        )
    }

    static func isAuthenticationFlowURL(_ url: URL?) -> Bool {
        guard let url,
              InstagramNavigationDelegate.isInstagramHost(url.host ?? "") else { return false }

        let path = url.path.lowercased()
        let authenticationPrefixes = [
            "/accounts/login",
            "/accounts/signup",
            "/accounts/emailsignup",
            "/accounts/password",
            "/accounts/two_factor",
            "/accounts/onetap",
            "/accounts/confirm",
            "/challenge",
            "/checkpoint"
        ]
        return authenticationPrefixes.contains { prefix in
            path == prefix || path.hasPrefix(prefix + "/")
        }
    }
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
