import Combine
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    @Published var selectedSection: InstagramSection = .home
    @Published private(set) var sessionState: InstagramSessionState = .unknown
    @Published var isSettingsPresented = false

    let policy: PolicyCoordinator
    let webViews: WebViewPool
    private let sessionManager = SessionManager()

    init() {
        let policy = PolicyCoordinator()
        self.policy = policy
        self.webViews = WebViewPool(policy: policy)
        webViews.sessionChanged = { [weak self] state in
            self?.setSessionState(state)
        }
    }

    func start() async {
        policy.refresh()
        guard !policy.dailyLimit.isLocked else { return }
        let hasSessionCookie = await sessionManager.hasInstagramCookies()
        let decision = InstagramSessionRouting.launchDecision(
            hasSessionCookie: hasSessionCookie
        )
        webViews.prepareHome(at: decision.initialHomeURL)
        setSessionState(decision.sessionState)
    }

    func scenePhaseChanged(_ phase: ScenePhase) {
        switch phase {
        case .active:
            policy.refresh()
            policy.dailyLimit.applicationBecameActive()
            guard !policy.dailyLimit.isLocked else { return }
            webViews.resumeSelected(selectedSection)
        case .inactive, .background:
            policy.dailyLimit.applicationResignedActive()
            webViews.pauseAllMedia()
        @unknown default:
            policy.dailyLimit.applicationResignedActive()
            webViews.pauseAllMedia()
        }
    }

    func select(_ section: InstagramSection) {
        guard !policy.dailyLimit.isLocked, section != selectedSection else { return }
        selectedSection = section
        HapticManager.selectionChanged()
        webViews.resumeSelected(section)
    }

    func signOut() async {
        await webViews.clearInstagramSession()
        selectedSection = .home
        isSettingsPresented = false
        setSessionState(.loggedOut)
    }

    private func setSessionState(_ state: InstagramSessionState) {
        guard state != .unknown else { return }

        // This is intentionally idempotent. Repeated logged-out reports from the
        // login DOM must not reload an in-progress login or challenge flow.
        if state == .loggedOut {
            webViews.showLogin()
        }

        guard state != sessionState else { return }
        let wasAuthenticated = sessionState == .authenticated
#if DEBUG
        NSLog("Instagram session state: %@ -> %@", sessionState.rawValue, state.rawValue)
#endif
        sessionState = state
        if state == .authenticated {
#if DEBUG
            NSLog("Instagram authenticated state detected; preparing persistent webviews")
#endif
            webViews.prepareAllSections()
            webViews.resumeSelected(selectedSection)
        } else if wasAuthenticated {
            selectedSection = .home
        }
    }
}
