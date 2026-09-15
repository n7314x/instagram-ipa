import Foundation
import WebKit

enum InstagramWebResourceManifest {
    // Every JavaScript file either bootstraps or enforces application policy.
    static let documentStartScriptNames = ["Bootstrap", "NavigationChromeFilter"]
    static let documentEndScriptNames = [
        "StoryFilter",
        "StoryViewerFilter",
        "NotificationFilter",
        "ReelsFilter",
        "MapFilter",
        "AdFilter",
        "SearchFilter",
        "CreationLimitBridge"
    ]
    static let presentationStylesheetName = "Presentation"

    static let requiredJavaScriptFileNames =
        (documentStartScriptNames + documentEndScriptNames).map { "\($0).js" }
    static let allFileNames = requiredJavaScriptFileNames + ["\(presentationStylesheetName).css"]
}

@MainActor
enum ScriptLoader {
    static func installScripts(
        into controller: WKUserContentController,
        snapshot: WebPolicySnapshot
    ) {
        let documentStartScripts = loadScripts(
            named: InstagramWebResourceManifest.documentStartScriptNames
        )
        let documentEndScripts = loadScripts(
            named: InstagramWebResourceManifest.documentEndScriptNames
        )
        let missingScripts = documentStartScripts.missing + documentEndScripts.missing

        guard missingScripts.isEmpty else {
            reportResourceProblem(
                "Required policy resources are missing or unreadable: \(missingScripts.joined(separator: ", "))"
            )
            installFailClosedScript(in: controller)
            return
        }

        controller.addUserScript(WKUserScript(
            source: policyPrelude(snapshot),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))

        if let css = resource(
            named: InstagramWebResourceManifest.presentationStylesheetName,
            extension: "css"
        ) {
            let encoded = try? JSONSerialization.data(withJSONObject: [css])
            let array = encoded.flatMap { String(data: $0, encoding: .utf8) } ?? "[\"\"]"
            let source = "(function(){var c=\(array)[0];function a(){var s=document.createElement('style');s.textContent=c;(document.head||document.documentElement).appendChild(s);}if(document.documentElement){a();}else{document.addEventListener('DOMContentLoaded',a,{once:true});}}());"
            controller.addUserScript(WKUserScript(
                source: source,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: true
            ))
        } else {
            let name = InstagramWebResourceManifest.presentationStylesheetName
            reportResourceProblem("Presentation resource is missing or unreadable: \(name).css")
        }

        for source in documentStartScripts.sources {
            addScript(source: source, time: .atDocumentStart, to: controller)
        }
        for source in documentEndScripts.sources {
            addScript(source: source, time: .atDocumentEnd, to: controller)
        }
    }

    private static func loadScripts(named names: [String]) -> (sources: [String], missing: [String]) {
        var sources: [String] = []
        var missing: [String] = []
        for name in names {
            if let source = resource(named: name, extension: "js") {
                sources.append(source)
            } else {
                missing.append("\(name).js")
            }
        }
        return (sources, missing)
    }

    private static func addScript(
        source: String,
        time: WKUserScriptInjectionTime,
        to controller: WKUserContentController
    ) {
        controller.addUserScript(WKUserScript(
            source: source,
            injectionTime: time,
            forMainFrameOnly: true
        ))
    }

    private static func resource(named name: String, extension fileExtension: String) -> String? {
        guard let url = Bundle.main.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: nil
        ) else {
            return nil
        }
        do {
            return try String(contentsOf: url, encoding: .utf8)
        } catch {
            NSLog("Instagram ScriptLoader could not read %@: %@", url.lastPathComponent, error.localizedDescription)
            return nil
        }
    }

    private static func reportResourceProblem(_ message: String) {
        NSLog("Instagram ScriptLoader: %@", message)
#if DEBUG
        assertionFailure(message)
#endif
    }

    private static func installFailClosedScript(in controller: WKUserContentController) {
        controller.addUserScript(WKUserScript(
            source: failClosedJavaScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
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

    /// If a required policy script is absent in Release, leave the native shell
    /// running but make Instagram content unusable instead of weakening policy.
    private static let failClosedJavaScript = """
    (function () {
      "use strict";
      const message = "Instagram is unavailable because required app resources could not be loaded.";
      const stopEvent = (event) => { event.preventDefault(); event.stopImmediatePropagation(); };
      document.addEventListener("click", stopEvent, true);
      document.addEventListener("submit", stopEvent, true);
      document.addEventListener("keydown", stopEvent, true);
      function block() {
        window.stop();
        if (!document.documentElement || document.getElementById("ig-resource-failure")) return;
        const notice = document.createElement("div");
        notice.id = "ig-resource-failure";
        notice.setAttribute("role", "alert");
        notice.textContent = message;
        notice.style.cssText = "position:fixed;inset:0;z-index:2147483647;display:flex;align-items:center;justify-content:center;padding:32px;background:#111;color:#fff;text-align:center;font:17px -apple-system,BlinkMacSystemFont,sans-serif";
        document.documentElement.appendChild(notice);
      }
      if (document.documentElement) block();
      else document.addEventListener("DOMContentLoaded", block, { once: true });
    }());
    """
}
