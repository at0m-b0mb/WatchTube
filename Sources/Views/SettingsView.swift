import SwiftUI

/// Region/language and optional advanced auth. Also states the privacy posture
/// plainly — no accounts, no analytics.
struct SettingsView: View {
    @AppStorage("hl") private var language = "en"
    @AppStorage("gl") private var region = "US"

    @State private var poToken = KeychainStore.get(KeychainStore.Keys.poToken) ?? ""
    @State private var visitorData = KeychainStore.get(KeychainStore.Keys.visitorData) ?? ""
    @State private var savedNote: String?

    var body: some View {
        List {
            Section("Region") {
                TextField("Language (hl)", text: $language)
                TextField("Country (gl)", text: $region)
            }

            Section {
                SecureField("PoToken", text: $poToken)
                SecureField("Visitor data", text: $visitorData)
                Button("Save") { save() }
                if let savedNote {
                    Text(savedNote)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("Optional. Only needed if certain videos refuse to play. Stored encrypted in the Keychain — never sent anywhere except YouTube.")
            }

            Section {
                Label("No accounts, no sign-in", systemImage: "person.crop.circle.badge.xmark")
                Label("No analytics or tracking", systemImage: "eye.slash")
                Label("HTTPS only (ATS enforced)", systemImage: "lock.fill")
            } header: {
                Text("Privacy")
            } footer: {
                Text("Searches and playback talk directly to YouTube. WatchTube keeps no history and phones no home.")
            }
        }
        .navigationTitle("Settings")
    }

    private func save() {
        KeychainStore.set(poToken, for: KeychainStore.Keys.poToken)
        KeychainStore.set(visitorData, for: KeychainStore.Keys.visitorData)
        savedNote = "Saved."
    }
}
