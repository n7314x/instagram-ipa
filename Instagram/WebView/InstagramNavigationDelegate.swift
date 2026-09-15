import UIKit
import WebKit

@MainActor
final class InstagramNavigationDelegate: NSObject, WKNavigationDelegate, WKUIDelegate {
    weak var bridge: InstagramBridgeHandler?
    var policySnapshot: () -> WebPolicySnapshot

    init(policySnapshot: @escaping () -> WebPolicySnapshot) {
        self.policySnapshot = policySnapshot
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if Self.isInstagramAppOpeningURL(url) {
#if DEBUG
            NSLog("Instagram app-open navigation blocked: %@", url.scheme ?? "unknown-scheme")
#endif
            decisionHandler(.cancel)
            return
        }

        if url.scheme == "about" {
            decisionHandler(.allow)
            return
        }

        guard url.scheme?.lowercased() == "https" else {
            decisionHandler(.cancel)
            return
        }

        if navigationAction.targetFrame?.isMainFrame == false {
            decisionHandler(.allow)
            return
        }

        guard Self.isInstagramOwned(url) else {
            UIApplication.shared.open(url)
            decisionHandler(.cancel)
            return
        }

        guard !InstagramRoutePolicy.isBlocked(url, snapshot: policySnapshot()) else {
            decisionHandler(.cancel)
            bridge?.showBlockedNotice(in: webView)
            return
        }

        decisionHandler(.allow)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard navigationAction.targetFrame == nil,
              let url = navigationAction.request.url else { return nil }

        if Self.isInstagramAppOpeningURL(url) {
#if DEBUG
            NSLog("Instagram app-open window request blocked: %@", url.scheme ?? "unknown-scheme")
#endif
        } else if Self.isInstagramOwned(url), !InstagramRoutePolicy.isBlocked(url, snapshot: policySnapshot()) {
            webView.load(navigationAction.request)
        } else if url.scheme?.lowercased() == "https" {
            UIApplication.shared.open(url)
        }
        return nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
        bridge?.requestPageAssessment(in: webView)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        webView.reload()
    }

    func webView(
        _ webView: WKWebView,
        requestMediaCapturePermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        type: WKMediaCaptureType,
        decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void
    ) {
        decisionHandler(Self.isInstagramHost(origin.host) ? .prompt : .deny)
    }

    func webView(
        _ webView: WKWebView,
        requestGeolocationPermissionFor origin: WKSecurityOrigin,
        initiatedByFrame frame: WKFrameInfo,
        decisionHandler: @escaping @MainActor @Sendable (WKPermissionDecision) -> Void
    ) {
        // Instagram Map and location sharing are intentionally unavailable.
        decisionHandler(.deny)
    }

    nonisolated static func isInstagramOwned(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        return isInstagramHost(host) || host == "facebook.com" || host.hasSuffix(".facebook.com")
    }

    nonisolated static func isInstagramHost(_ host: String) -> Bool {
        let normalized = host.lowercased()
        return normalized == "instagram.com" || normalized.hasSuffix(".instagram.com")
    }

    nonisolated static func isInstagramAppOpeningURL(_ url: URL) -> Bool {
        let scheme = url.scheme?.lowercased()
        if scheme == "instagram" || scheme == "instagram-stories" {
            return true
        }
        if scheme == "intent" {
            return url.absoluteString.localizedCaseInsensitiveContains("instagram")
        }

        let host = url.host?.lowercased()
        guard host == "apps.apple.com" || host == "itunes.apple.com" else { return false }
        return (url.path + "?" + (url.query ?? ""))
            .localizedCaseInsensitiveContains("instagram")
    }
}

enum InstagramRoutePolicy {
    private static let storyCreationFragments = ["/stories/create", "/create/story"]
    private static let noteCreationFragments = ["/notes/create", "/create/note"]

    static func isBlocked(_ url: URL, snapshot: WebPolicySnapshot) -> Bool {
        let path = url.path.lowercased()
        let pathComponents = path.split(separator: "/").map(String.init)
        let components = Set(pathComponents)
        let firstComponent = pathComponents.first
        let isMapRoot = firstComponent.map {
            ["instagram-map", "location_sharing", "location-sharing"].contains($0)
        } ?? false
        let containsDirectMap = zip(pathComponents, pathComponents.dropFirst()).contains { pair in
            pair.0 == "direct" && pair.1 == "map"
        }
        let blockedViewerComponents: Set<String> = [
            "viewers", "story_viewers", "story-viewers", "seen_by", "seen-by"
        ]
        let isViewerRoute = pathComponents.count > 1 && !components.isDisjoint(with: blockedViewerComponents)
        if isMapRoot || containsDirectMap || isViewerRoute {
            return true
        }
        if snapshot.storyPostsRemaining == 0,
           storyCreationFragments.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }
        if snapshot.notePostsRemaining == 0,
           noteCreationFragments.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) {
            return true
        }
        if let username = storyUsername(from: url),
           !snapshot.allowedStoryUsernames.contains(username) {
            return true
        }
        return false
    }

    static func storyUsername(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard parts.count >= 2, parts[0].lowercased() == "stories" else { return nil }
        let username = parts[1].lowercased()
        guard !["archive", "create", "highlights"].contains(username) else { return nil }
        guard username.range(of: #"^[a-z0-9._]+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return username
    }
}
