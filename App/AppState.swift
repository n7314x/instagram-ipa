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
        _ = webViews.webView(for: .home)
        if await sessionManager.hasInstagramCookies() {
            setSessionState(.authenticated)
        } else {
            setSessionState(.loggedOut)
        }
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
        sessionState = .loggedOut
        isSettingsPresented = false
    }

    private func setSessionState(_ state: InstagramSessionState) {
        guard state != .unknown, state != sessionState else { return }
        let wasAuthenticated = sessionState == .authenticated
        sessionState = state
        if state == .authenticated {
            webViews.prepareAllSections()
            webViews.resumeSelected(selectedSection)
        } else if wasAuthenticated {
            selectedSection = .home
            webViews.showLogin()
        }
    }
}
