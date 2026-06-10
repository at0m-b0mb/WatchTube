import Foundation

/// Builds an `InnerTubeClient` pre-loaded with any optional advanced secrets the
/// user saved in Settings (Keychain-backed). Centralized so every screen
/// resolves streams the same way.
enum AppClient {
    static func make() -> InnerTubeClient {
        var client = InnerTubeClient()

        // Region/language come from Settings so non-US users get local results.
        let defaults = UserDefaults.standard
        if let language = defaults.string(forKey: "hl"), !language.isEmpty {
            client.language = language
        }
        if let region = defaults.string(forKey: "gl"), !region.isEmpty {
            client.region = region
        }

        client.poToken = KeychainStore.get(KeychainStore.Keys.poToken)
        client.visitorData = KeychainStore.get(KeychainStore.Keys.visitorData)
        return client
    }
}
