import Foundation
import Security

/// Minimal Keychain wrapper for the handful of small secrets this app keeps
/// (the optional, advanced PoToken / visitor-data values).
///
/// Why the Keychain and not UserDefaults? Keychain entries are encrypted at
/// rest and gated by the device passcode. We use `AfterFirstUnlock` so playback
/// can resume after a reboot without re-prompting, while still keeping the data
/// off-device-readable when the watch is locked and powered down.
enum KeychainStore {
    enum Keys {
        static let poToken = "poToken"
        static let visitorData = "visitorData"
        static let googleAccessToken = "google.accessToken"
        static let googleRefreshToken = "google.refreshToken"
        static let googleTokenExpiry = "google.tokenExpiry"
    }

    private static let service = "com.at0m.watchtube"

    /// Stores `value`, or clears the entry when `value` is nil/empty.
    static func set(_ value: String?, for key: String) {
        guard let value, !value.isEmpty, let data = value.data(using: .utf8) else {
            remove(key)
            return
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var insert = query
            insert.merge(attributes) { _, new in new }
            SecItemAdd(insert as CFDictionary, nil)
        }
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
