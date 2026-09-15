import Foundation
import WebKit

@MainActor
enum ScriptLoader {
    static let documentStartScripts = ["Bootstrap"]
    static let documentEndScripts = [
        "StoryFilter",
        "StoryViewerFilter",
        "NotificationFilter",
        "ReelsFilter",
        "MapFilter",
        "AdFilter",
        "SearchFilter",
        "CreationLimitBridge"
    ]

    static func installScripts(
        into controller: WKUserContentController,
        snapshot: WebPolicySnapshot
    ) {
        controller.addUserScript(WKUserScript(
            source: policyPrelude(snapshot),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        if let css = resource(named: "Presentation", extension: "css") {
            let encoded = try? JSONSerialization.data(withJSONObject: [css])
            let array = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
            let source = "(function(){var c=\(array)[0];function a(){var s=document.createElement('style');s.textContent=c;(document.head||document.documentElement).appendChild(s);}if(document.documentElement){a();}else{document.addEventListener('DOMContentLoaded',a,{once:true});}}());"
            controller.addUserScript(WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        }

        for name in documentStartScripts {
            addResource(named: name, time: .atDocumentStart, to: controller)
        }
        for name in documentEndScripts {
            addResource(named: name, time: .atDocumentEnd, to: controller)
        }
    }

    private static func addResource(
        named name: String,
        time: WKUserScriptInjectionTime,
        to controller: WKUserContentController
    ) {
        guard let source = resource(named: name, extension: "js") else {
            assertionFailure("Missing bundled script: \(name).js")
            return
        }
        controller.addUserScript(WKUserScript(
            source: source,
            injectionTime: time,
            forMainFrameOnly: true
        ))
    }

    private static func resource(named name: String, extension fileExtension: String) -> String? {
        guard let url = Bundle.main.url(forResource: name, withExtension: fileExtension) else { return nil }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func policyPrelude(_ snapshot: WebPolicySnapshot) -> String {
        "window.__IG_NATIVE_POLICY__ = Object.freeze(\(policyJSON(snapshot)));"
    }

    static func policyUpdateJavaScript(_ snapshot: WebPolicySnapshot) -> String {
        "window.__IG_NATIVE_POLICY__ = Object.freeze(\(policyJSON(snapshot))); window.IGShield && window.IGShield.runFilters();"
    }

    private static func policyJSON(_ snapshot: WebPolicySnapshot) -> String {
        let object: [String: Any] = [
            "allowedStoryUsernames": snapshot.allowedStoryUsernames.sorted(),
            "storyPostsRemaining": snapshot.storyPostsRemaining,
            "notePostsRemaining": snapshot.notePostsRemaining
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
              let json = String(data: data, encoding: .utf8) else {
            return "{\"allowedStoryUsernames\":[],\"storyPostsRemaining\":0,\"notePostsRemaining\":0}"
        }
        return json
    }
}
