import SwiftUI

struct SettingsView: View {
    @Environment(LibraryStore.self) private var library
    @AppStorage("hl") private var language = "en"
    @AppStorage("gl") private var region = "US"
    @AppStorage("dataSaver") private var dataSaver = false
    @AppStorage("autoplay") private var autoplay = true
    @AppStorage("defaultSpeed") private var defaultSpeed = 1.0

    @State private var poToken = KeychainStore.get(KeychainStore.Keys.poToken) ?? ""
    @State private var visitorData = KeychainStore.get(KeychainStore.Keys.visitorData) ?? ""
    @State private var savedNote: String?

    private var auth: GoogleAuth { .shared }

    var body: some View {
        List {
            Section {
                if auth.isSignedIn {
                    Label("Signed in with Google", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Button(role: .destructive) {
                        auth.signOut()
                        Haptics.tap()
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } else {
                    NavigationLink {
                        GoogleSignInView()
                    } label: {
                        Label("Sign in with Google", systemImage: "person.crop.circle.badge.plus")
                    }
                }
            } header: {
                Text("Account")
            } footer: {
                Text(auth.isSignedIn
                     ? "Playback uses your YouTube account, which unlocks videos that refuse to play anonymously. The token only grants YouTube access \u{2014} never email or anything else."
                     : "Optional. Signing in unlocks videos that refuse to play anonymously. Access is YouTube-only; signed out, the app stays fully keyless.")
            }

            Section {
                Toggle(isOn: $dataSaver) {
                    Label("Data Saver", systemImage: "antenna.radiowaves.left.and.right")
                }
                Toggle(isOn: $autoplay) {
                    Label("Autoplay Next", systemImage: "play.fill")
                }
                Picker(selection: $defaultSpeed) {
                    Text("0.75x").tag(0.75)
                    Text("Normal").tag(1.0)
                    Text("1.25x").tag(1.25)
                    Text("1.5x").tag(1.5)
                    Text("2x").tag(2.0)
                } label: {
                    Label("Default Speed", systemImage: "gauge.with.dots.needle.33percent")
                }
            } header: {
                Text("Playback")
            } footer: {
                Text("Data Saver caps video to ~0.9 Mbps. Default Speed applies when starting a new video.")
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
                Text("Optional, and usually unnecessary when signed in. Stored encrypted in the Keychain \u{2014} never sent anywhere except YouTube.")
            }

            Section("Library") {
                Button(role: .destructive) {
                    library.clearHistory()
                    Haptics.tap()
                } label: {
                    Label("Clear History", systemImage: "clock.arrow.circlepath")
                }
                Button(role: .destructive) {
                    library.clearRecentSearches()
                    Haptics.tap()
                } label: {
                    Label("Clear Recent Searches", systemImage: "magnifyingglass")
                }
                Button(role: .destructive) {
                    library.clearQueue()
                    Haptics.tap()
                } label: {
                    Label("Clear Queue", systemImage: "text.badge.minus")
                }
            }

            Section {
                Label("Sign-in optional, keyless by default", systemImage: "person.crop.circle.badge.questionmark")
                Label("No analytics or tracking", systemImage: "eye.slash")
                Label("HTTPS only (ATS enforced)", systemImage: "lock.fill")
            } header: {
                Text("Privacy")
            } footer: {
                Text("Searches and playback talk directly to YouTube. Tokens stay in the Keychain, history stays on the watch, and WatchTube phones no home.")
            }

            Section {
                HStack {
                    Text("WatchTube")
                    Spacer()
                    Text(version).foregroundStyle(.secondary)
                }
                .font(.caption2)
                expiryRow
            }
        }
        .navigationTitle("Settings")
        .brandBackdrop()
    }

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        return "v\(v)"
    }

    @ViewBuilder private var expiryRow: some View {
        let info = ProvisioningInfo.self
        HStack {
            Image(systemName: expiryIcon)
                .foregroundStyle(expiryColor)
                .font(.caption2)
            Text(info.summary)
                .font(.caption2)
            Spacer()
            if !info.isPaid {
                Text("Free ID")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var expiryColor: Color {
        switch ProvisioningInfo.urgency {
        case .ok: .green
        case .soon: .yellow
        case .expired: .red
        }
    }

    private var expiryIcon: String {
        switch ProvisioningInfo.urgency {
        case .ok: "checkmark.shield"
        case .soon: "exclamationmark.shield"
        case .expired: "xmark.shield"
        }
    }

    private func save() {
        KeychainStore.set(poToken, for: KeychainStore.Keys.poToken)
        KeychainStore.set(visitorData, for: KeychainStore.Keys.visitorData)
        savedNote = "Saved."
        Haptics.success()
    }
}
