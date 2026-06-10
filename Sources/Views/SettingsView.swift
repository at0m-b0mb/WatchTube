import SwiftUI

/// Playback prefs, region/language, optional advanced auth, library controls,
/// and a plain statement of the privacy posture.
struct SettingsView: View {
    @Environment(LibraryStore.self) private var library
    @AppStorage("hl") private var language = "en"
    @AppStorage("gl") private var region = "US"
    @AppStorage("dataSaver") private var dataSaver = false

    @State private var poToken = KeychainStore.get(KeychainStore.Keys.poToken) ?? ""
    @State private var visitorData = KeychainStore.get(KeychainStore.Keys.visitorData) ?? ""
    @State private var savedNote: String?

    var body: some View {
        List {
            Section {
                Toggle(isOn: $dataSaver) {
                    Label("Data Saver", systemImage: "antenna.radiowaves.left.and.right")
                }
            } header: {
                Text("Playback")
            } footer: {
                Text("Caps video to ~0.9 Mbps to save cellular data and battery.")
            }

            Section("Region") {
                TextField("Language (hl)", text: $language)
                TextField("Country (gl)", text: $region)
            }

            Section {
                SecureField("PoToken", text: $poToken)
                SecureField("Visitor data", text: $visitorData)
                Button("Save") { save() }
                if let savedNote {
                    Text(savedNote).font(.caption2).foregroundStyle(.secondary)
                }
            } header: {
                Text("Advanced")
            } footer: {
                Text("Optional. Only needed if certain videos refuse to play. Stored encrypted in the Keychain — never sent anywhere except YouTube.")
            }

            Section("Library") {
                Button(role: .destructive) {
                    library.clearHistory()
                    Haptics.tap()
                } label: {
                    Label("Clear History", systemImage: "clock.arrow.circlepath")
                }
            }

            Section {
                Label("No accounts, no sign-in", systemImage: "person.crop.circle.badge.xmark")
                Label("No analytics or tracking", systemImage: "eye.slash")
                Label("HTTPS only (ATS enforced)", systemImage: "lock.fill")
            } header: {
                Text("Privacy")
            } footer: {
                Text("Searches and playback talk directly to YouTube. WatchTube keeps no history off-device and phones no home.")
            }

            Section {
                HStack {
                    Text("WatchTube")
                    Spacer()
                    Text(version).foregroundStyle(.secondary)
                }
                .font(.caption2)
            }
        }
        .navigationTitle("Settings")
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }

    private func save() {
        KeychainStore.set(poToken, for: KeychainStore.Keys.poToken)
        KeychainStore.set(visitorData, for: KeychainStore.Keys.visitorData)
        savedNote = "Saved."
        Haptics.success()
    }
}
