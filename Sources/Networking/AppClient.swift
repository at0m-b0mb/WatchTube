import Foundation

/// Builds an `InnerTubeClient` pre-loaded with the user's saved settings and —
/// when signed in with Google — a fresh bearer token. Centralized so every
/// screen resolves streams the same way.
enum AppClient {
    static func make() async -> InnerTubeClient {
        var client = InnerTubeClient()

        // Region/language come from Settings so non-US users get local results.
        let defaults = UserDefaults.standard
        if let language = defaults.string(forKey: "hl"), !language.isEmpty {
            client.language = language
        }
        if let region = defaults.string(forKey: "gl"), !region.isEmpty {
            client.region = region
        }
        client.dataSaver = defaults.bool(forKey: "dataSaver")

        client.poToken = KeychainStore.get(KeychainStore.Keys.poToken)
        client.visitorData = KeychainStore.get(KeychainStore.Keys.visitorData)

        // Signed in with Google? Playback rides on the user's YouTube account.
        // nil means keyless mode — exactly the old behavior.
        client.authorization = await GoogleAuth.shared.validAccessToken()
        return client
    }
}
