import Foundation
import WebKit

struct WebPolicySnapshot: Equatable, Sendable {
    let allowedStoryUsernames: Set<String>
    let storyPostsRemaining: Int
    let notePostsRemaining: Int
}

@MainActor
protocol InstagramBridgeDelegate: AnyObject {
    func bridgeShouldAllowCreation(_ kind: CreationKind) -> Bool
    func bridgeDidDiscoverProfileURL(_ url: URL)
    func bridgeDidDetectSession(_ state: InstagramSessionState)
}

@MainActor
final class InstagramBridgeHandler: NSObject, WKScriptMessageHandlerWithReply {
    static let messageName = "instagramPolicy"
    weak var delegate: InstagramBridgeDelegate?

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard message.name == Self.messageName,
              isTrusted(origin: message.frameInfo.securityOrigin),
              let body = message.body as? [String: Any],
              let event = body["event"] as? String else {
            replyHandler(false, nil)
            return
        }

        switch event {
        case "storyPublishAttempt":
            replyHandler(delegate?.bridgeShouldAllowCreation(.story) ?? false, nil)
        case "notePublishAttempt":
            replyHandler(delegate?.bridgeShouldAllowCreation(.note) ?? false, nil)
        case "profileDiscovered":
            guard let rawURL = body["url"] as? String,
                  rawURL.count <= 300,
                  let url = URL(string: rawURL),
                  InstagramNavigationDelegate.isInstagramOwned(url) else {
                replyHandler(false, nil)
                return
            }
            delegate?.bridgeDidDiscoverProfileURL(url)
            replyHandler(true, nil)
        case "sessionState":
            guard let rawState = body["state"] as? String,
                  let state = InstagramSessionState(rawValue: rawState) else {
                replyHandler(false, nil)
                return
            }
            delegate?.bridgeDidDetectSession(state)
            replyHandler(true, nil)
        default:
            replyHandler(false, nil)
        }
    }

    func requestPageAssessment(in webView: WKWebView) {
        webView.evaluateJavaScript("window.IGShield && window.IGShield.assessPage();")
    }

    func showBlockedNotice(in webView: WKWebView) {
        webView.evaluateJavaScript("window.IGShield && window.IGShield.showBlockedNotice();")
    }

    private func isTrusted(origin: WKSecurityOrigin) -> Bool {
        guard origin.protocol.lowercased() == "https" else { return false }
        let host = origin.host.lowercased()
        return host == "instagram.com" || host.hasSuffix(".instagram.com")
    }
}

/// A weak forwarding object prevents WKUserContentController from retaining the
/// bridge owner through its message-handler table.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandlerWithReply {
    weak var target: (any WKScriptMessageHandlerWithReply)?

    init(target: any WKScriptMessageHandlerWithReply) {
        self.target = target
    }

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage,
        replyHandler: @escaping @MainActor @Sendable (Any?, String?) -> Void
    ) {
        guard let target else {
            replyHandler(false, nil)
            return
        }
        target.userContentController(
            userContentController,
            didReceive: message,
            replyHandler: replyHandler
        )
    }
}
