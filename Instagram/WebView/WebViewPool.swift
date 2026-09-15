import Combine
import Foundation
import WebKit

enum InstagramSection: Int, CaseIterable, Identifiable, Sendable {
    case home
    case search
    case reels
    case messages
    case profile

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .search: "Search"
        case .reels: "Reels"
        case .messages: "Messages"
        case .profile: "Profile"
        }
    }

    var symbol: String {
        switch self {
        case .home: "house"
        case .search: "magnifyingglass"
        case .reels: "play.rectangle"
        case .messages: "paperplane"
        case .profile: "person.crop.circle"
        }
    }

    var selectedSymbol: String {
        switch self {
        case .home: "house.fill"
        case .search: "magnifyingglass"
        case .reels: "play.rectangle.fill"
        case .messages: "paperplane.fill"
        case .profile: "person.crop.circle.fill"
        }
    }

    var initialURL: URL {
        let path: String
        switch self {
        case .home: path = "/"
        case .search: path = "/explore/search/"
        case .reels: path = "/reels/"
        case .messages: path = "/direct/inbox/"
        case .profile: path = "/"
        }
        return URL(string: "https://www.instagram.com\(path)")!
    }
}

@MainActor
final class WebViewPool: NSObject, ObservableObject, InstagramBridgeDelegate {
    private let dataStore = WKWebsiteDataStore.default()
    private let policy: PolicyCoordinator
    private var entries: [InstagramSection: Entry] = [:]
    private var discoveredProfileURL: URL?

    var sessionChanged: (InstagramSessionState) -> Void = { _ in }

    init(policy: PolicyCoordinator) {
        self.policy = policy
        super.init()
    }

    func webView(for section: InstagramSection) -> WKWebView {
        if let existing = entries[section] {
            return existing.webView
        }

        let contentController = WKUserContentController()
        let bridge = InstagramBridgeHandler()
        bridge.delegate = self
        let weakHandler = WeakScriptMessageHandler(target: bridge)
        contentController.addScriptMessageHandler(
            weakHandler,
            contentWorld: .page,
            name: InstagramBridgeHandler.messageName
        )

        let snapshot = currentSnapshot
        ScriptLoader.installScripts(into: contentController, snapshot: snapshot)

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = dataStore
        configuration.userContentController = contentController
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []

        let navigationDelegate = InstagramNavigationDelegate(
            policySnapshot: { [weak self] in self?.currentSnapshot ?? snapshot }
        )
        navigationDelegate.bridge = bridge

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = navigationDelegate
        webView.uiDelegate = navigationDelegate
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.isDirectionalLockEnabled = true
        webView.allowsBackForwardNavigationGestures = false
        webView.backgroundColor = .systemBackground
        webView.isOpaque = true
#if DEBUG
        webView.isInspectable = true
#endif

        entries[section] = Entry(
            webView: webView,
            bridge: bridge,
            weakHandler: weakHandler,
            navigationDelegate: navigationDelegate,
            contentController: contentController
        )

        let url = section == .profile ? (discoveredProfileURL ?? section.initialURL) : section.initialURL
        webView.load(URLRequest(url: url, cachePolicy: .useProtocolCachePolicy))
        return webView
    }

    func prepareAllSections() {
        for section in InstagramSection.allCases {
            _ = webView(for: section)
        }
    }

    func suspendAll() {
        for entry in entries.values {
            if entry.webView.isLoading {
                entry.wasStoppedByPolicy = true
                entry.webView.stopLoading()
            }
            pauseMedia(in: entry.webView)
        }
    }

    func pauseAllMedia() {
        for entry in entries.values {
            pauseMedia(in: entry.webView)
        }
    }

    func resumeSelected(_ section: InstagramSection) {
        let webView = webView(for: section)
        if let entry = entries[section], entry.wasStoppedByPolicy {
            entry.wasStoppedByPolicy = false
            webView.reload()
        } else if webView.url == nil {
            webView.load(URLRequest(url: section.initialURL))
        }
        for (otherSection, entry) in entries where otherSection != section {
            pauseMedia(in: entry.webView)
        }
    }

    func reloadPolicyScripts() {
        // Replace the document-start snapshot for future SPA document loads, then
        // update every existing page immediately without reloading it.
        let snapshot = currentSnapshot
        let json = ScriptLoader.policyUpdateJavaScript(snapshot)
        for entry in entries.values {
            entry.contentController.removeAllUserScripts()
            ScriptLoader.installScripts(into: entry.contentController, snapshot: snapshot)
            entry.webView.evaluateJavaScript(json)
        }
    }

    func clearInstagramSession() async {
        let types = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await withCheckedContinuation { continuation in
            dataStore.fetchDataRecords(ofTypes: types) { continuation.resume(returning: $0) }
        }
        let instagramRecords = records.filter {
            let name = $0.displayName.lowercased()
            return name.contains("instagram") || name.contains("facebook")
        }
        await withCheckedContinuation { continuation in
            dataStore.removeData(ofTypes: types, for: instagramRecords) {
                continuation.resume()
            }
        }

        discoveredProfileURL = nil

        for entry in entries.values {
            entry.webView.load(URLRequest(url: InstagramSection.home.initialURL))
        }
    }

    func showLogin() {
        guard let url = URL(string: "https://www.instagram.com/accounts/login/") else { return }
        webView(for: .home).load(URLRequest(url: url))
    }

    func bridgeShouldAllowCreation(_ kind: CreationKind) -> Bool {
        let allowed = policy.recordFinalPublishAttempt(kind)
        reloadPolicyScripts()
        return allowed
    }

    func bridgeDidDiscoverProfileURL(_ url: URL) {
        guard url.pathComponents.count >= 2,
              !url.path.hasPrefix("/accounts"),
              !url.path.hasPrefix("/explore"),
              !url.path.hasPrefix("/direct") else { return }
        discoveredProfileURL = url
        guard let profile = entries[.profile]?.webView,
              profile.url == InstagramSection.profile.initialURL else { return }
        profile.load(URLRequest(url: url))
    }

    func bridgeDidDetectSession(_ state: InstagramSessionState) {
        sessionChanged(state)
    }

    private var currentSnapshot: WebPolicySnapshot {
        WebPolicySnapshot(
            allowedStoryUsernames: Set(AppPolicy.allowedStoryUsernames.map { $0.lowercased() }),
            storyPostsRemaining: policy.storyPostsRemaining,
            notePostsRemaining: policy.notePostsRemaining
        )
    }

    private func pauseMedia(in webView: WKWebView) {
        webView.evaluateJavaScript(
            "document.querySelectorAll('video,audio').forEach(function(media){media.pause();});"
        )
    }

    private final class Entry {
        let webView: WKWebView
        let bridge: InstagramBridgeHandler
        let weakHandler: WeakScriptMessageHandler
        let navigationDelegate: InstagramNavigationDelegate
        let contentController: WKUserContentController
        var wasStoppedByPolicy = false

        init(
            webView: WKWebView,
            bridge: InstagramBridgeHandler,
            weakHandler: WeakScriptMessageHandler,
            navigationDelegate: InstagramNavigationDelegate,
            contentController: WKUserContentController
        ) {
            self.webView = webView
            self.bridge = bridge
            self.weakHandler = weakHandler
            self.navigationDelegate = navigationDelegate
            self.contentController = contentController
        }
    }
}
