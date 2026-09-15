import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @AppStorage("appearance") private var appearance = AppAppearance.system.rawValue
    @Environment(\.dismiss) private var dismiss
    @State private var showSignOutConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Appearance") {
                    Picker("Appearance", selection: $appearance) {
                        ForEach(AppAppearance.allCases) { choice in
                            Text(choice.title).tag(choice.rawValue)
                        }
                    }
                }

                Section {
                    Text("Daily usage, Story and Note quotas, Story filtering, Map removal, swipe navigation, and haptics are fixed policies and cannot be changed here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button("Sign Out", role: .destructive) {
                        showSignOutConfirmation = true
                    }
                } footer: {
                    Text("Sign Out removes Instagram and Facebook website data stored by this app. It is never removed during a normal launch.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.glass)
                }
            }
            .confirmationDialog(
                "Sign out of Instagram?",
                isPresented: $showSignOutConfirmation,
                titleVisibility: .visible
            ) {
                Button("Sign Out", role: .destructive) {
                    Task { await appState.signOut() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You will need to log in again using Instagram's website.")
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackgroundInteraction(.enabled(upThrough: .medium))
    }
}
