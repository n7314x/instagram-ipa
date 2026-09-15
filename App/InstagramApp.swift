import SwiftUI

@main
struct InstagramApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView(appState: appState)
                .preferredColorScheme(AppAppearance(rawValue: appearance)?.colorScheme)
                .task {
                    await appState.start()
                    appState.scenePhaseChanged(scenePhase)
                }
                .onChange(of: scenePhase) { _, newPhase in
                    appState.scenePhaseChanged(newPhase)
                }
        }
    }
}

private struct RootView: View {
    @ObservedObject var appState: AppState
    @ObservedObject private var dailyLimit: DailyLimitController

    init(appState: AppState) {
        self.appState = appState
        self.dailyLimit = appState.policy.dailyLimit
    }

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            if dailyLimit.isLocked {
                DailyLimitLockView(nextUnlockDate: dailyLimit.nextUnlockDate)
                    .transition(.opacity)
            } else if appState.sessionState == .authenticated {
                authenticatedShell
                    .transition(.opacity)
            } else {
                InstagramWebView(webView: appState.webViews.webView(for: .home))
                    .ignoresSafeArea(.container, edges: .bottom)
                    .overlay {
                        if appState.sessionState == .unknown {
                            ProgressView().controlSize(.large)
                        }
                    }
            }
        }
        .animation(.easeInOut(duration: 0.2), value: dailyLimit.isLocked)
        .sheet(isPresented: $appState.isSettingsPresented) {
            SettingsView(appState: appState)
        }
        .onChange(of: dailyLimit.isLocked) { _, isLocked in
            if isLocked {
                appState.webViews.suspendAll()
                appState.isSettingsPresented = false
            } else {
                Task { await appState.start() }
            }
        }
    }

    private var authenticatedShell: some View {
        MainPager(
            selection: Binding(
                get: { appState.selectedSection },
                set: { appState.select($0) }
            ),
            webViews: appState.webViews
        )
        .overlay(alignment: .bottom) {
            GlassTabBar(
                selection: appState.selectedSection,
                onSelect: appState.select,
                onOpenSettings: { appState.isSettingsPresented = true }
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }
}
