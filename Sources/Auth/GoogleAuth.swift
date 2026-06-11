import Foundation
import Observation

// ─────────────────────────────────────────────────────────────────────────────
//  GoogleAuth — optional Google sign-in via the OAuth "device flow"
// ─────────────────────────────────────────────────────────────────────────────
//
//  The watch can't show Google's web sign-in page, so we use the same flow
//  YouTube on TV uses (RFC 8628): the watch shows a short code, you type it
//  into google.com/device on your phone, and Google hands the watch a token.
//
//    • Scope is YouTube-only. WatchTube never sees your email, contacts, or
//      anything else on your Google account.
//    • Tokens live in the Keychain. Signing out wipes them and revokes the
//      grant server-side.
//    • Signed out? The app stays fully keyless and works exactly as before —
//      sign-in only exists to unlock videos that refuse to play anonymously.
//
//  The client id/secret below are the public values baked into YouTube on TV —
//  the same kind of public constants as the InnerTube keys in
//  InnerTubeClient.swift. They are not secrets and are not tied to you.
//  Like everything InnerTube-adjacent, Google may break this flow someday;
//  when that happens the app simply behaves as signed-out.
// ─────────────────────────────────────────────────────────────────────────────

@MainActor
@Observable
final class GoogleAuth {
    static let shared = GoogleAuth()

    enum Phase: Equatable {
        case signedOut
        case requestingCode
        case awaitingApproval(code: String, url: String)
        case signedIn
    }

    private(set) var phase: Phase
    private(set) var lastError: String?

    var isSignedIn: Bool {
        if case .signedIn = phase { return true }
        return false
    }

    // YouTube-on-TV public OAuth client (device-flow capable, YouTube scope).
    private static let clientID =
        "861556708454-d6dlm3lh05idd8npek18k6be8ba3oc68.apps.googleusercontent.com"
    private static let clientSecret = "SboVhoG9s0rNafixCSGGKXAT"
    private static let scope =
        "http://gdata.youtube.com https://www.googleapis.com/auth/youtube-paid-content"

    private static let deviceCodeURL = URL(string: "https://www.youtube.com/o/oauth2/device/code")!
    private static let tokenURL = URL(string: "https://www.youtube.com/o/oauth2/token")!
    private static let revokeURL = URL(string: "https://oauth2.googleapis.com/revoke")!

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var refreshTask: Task<String?, Never>?

    init() {
        phase = KeychainStore.get(KeychainStore.Keys.googleRefreshToken) == nil
            ? .signedOut : .signedIn
    }

    // MARK: - Sign-in flow

    func startSignIn() {
        guard !isSignedIn, pollTask == nil else { return }
        lastError = nil
        phase = .requestingCode
        pollTask = Task { [weak self] in
            await self?.runDeviceFlow()
            self?.pollTask = nil
        }
    }

    func cancelSignIn() {
        pollTask?.cancel()
        pollTask = nil
        if !isSignedIn { phase = .signedOut }
    }

    /// Clears local tokens and (best effort) revokes the grant with Google.
    func signOut() {
        let refreshToken = KeychainStore.get(KeychainStore.Keys.googleRefreshToken)
        clearTokens()
        phase = .signedOut
        guard let refreshToken else { return }
        let revokeURL = Self.revokeURL
        Task.detached {
            var request = URLRequest(url: revokeURL)
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = "token=\(formEncode(refreshToken))".data(using: .utf8)
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    // MARK: - Token access (used by AppClient)

    /// A bearer token with at least a minute of life left, refreshing if
    /// needed. Returns nil when signed out or when Google rejects the refresh —
    /// callers then just proceed keyless.
    func validAccessToken() async -> String? {
        guard isSignedIn else { return nil }

        if let token = KeychainStore.get(KeychainStore.Keys.googleAccessToken),
           let raw = KeychainStore.get(KeychainStore.Keys.googleTokenExpiry),
           let expiry = TimeInterval(raw),
           Date(timeIntervalSince1970: expiry) > Date.now.addingTimeInterval(60) {
            return token
        }

        if let inFlight = refreshTask { return await inFlight.value }
        let task = Task { await refreshAccessToken() }
        refreshTask = task
        let token = await task.value
        refreshTask = nil
        return token
    }

    // MARK: - Device flow internals

    private func runDeviceFlow() async {
        do {
            let grant = try await requestDeviceCode()
            phase = .awaitingApproval(code: grant.userCode, url: grant.verificationURL)
            try await pollForToken(grant)
            phase = .signedIn
            Haptics.success()
        } catch is CancellationError {
            if !isSignedIn { phase = .signedOut }
        } catch {
            lastError = (error as? AuthError)?.message ?? error.localizedDescription
            phase = .signedOut
        }
    }

    private func requestDeviceCode() async throws -> DeviceGrant {
        let data = try await postForm(Self.deviceCodeURL, [
            "client_id": Self.clientID,
            "scope": Self.scope
        ])
        if let grant = try? JSONDecoder().decode(DeviceGrant.self, from: data) {
            return grant
        }
        throw AuthError(oauthErrorMessage(in: data)
            ?? "Google didn't issue a sign-in code. Try again later.")
    }

    private func pollForToken(_ grant: DeviceGrant) async throws {
        let deadline = Date.now.addingTimeInterval(grant.expiresIn)
        var interval = max(grant.interval ?? 5, 3)

        while Date.now < deadline {
            try await Task.sleep(for: .seconds(interval))
            let data = try await postForm(Self.tokenURL, [
                "client_id": Self.clientID,
                "client_secret": Self.clientSecret,
                "code": grant.deviceCode,
                "grant_type": "http://oauth.net/grant_type/device/1.0"
            ])
            let token = try? JSONDecoder().decode(TokenResponse.self, from: data)

            if let token, let access = token.accessToken {
                storeTokens(access: access,
                            refresh: token.refreshToken,
                            expiresIn: token.expiresIn ?? 3600)
                return
            }
            switch token?.error {
            case "authorization_pending":
                continue
            case "slow_down":
                interval += 3
            case "expired_token":
                throw AuthError("The code expired before it was entered. Try again.")
            case "access_denied":
                throw AuthError("Sign-in was declined on the other device.")
            default:
                throw AuthError(token?.errorDescription ?? token?.error
                    ?? "Google returned an unexpected reply. Try again.")
            }
        }
        throw AuthError("The code expired before it was entered. Try again.")
    }

    private func refreshAccessToken() async -> String? {
        guard let refreshToken = KeychainStore.get(KeychainStore.Keys.googleRefreshToken) else {
            return nil
        }
        guard let data = try? await postForm(Self.tokenURL, [
            "client_id": Self.clientID,
            "client_secret": Self.clientSecret,
            "refresh_token": refreshToken,
            "grant_type": "refresh_token"
        ]) else { return nil }   // transient network trouble: stay signed in, go keyless this once

        guard let token = try? JSONDecoder().decode(TokenResponse.self, from: data) else { return nil }
        if let access = token.accessToken {
            storeTokens(access: access, refresh: token.refreshToken, expiresIn: token.expiresIn ?? 3600)
            return access
        }
        if token.error == "invalid_grant" {
            // Token revoked server-side (e.g. from myaccount.google.com) —
            // drop to keyless mode cleanly.
            clearTokens()
            phase = .signedOut
        }
        return nil
    }

    // MARK: - Storage

    private func storeTokens(access: String, refresh: String?, expiresIn: Double) {
        KeychainStore.set(access, for: KeychainStore.Keys.googleAccessToken)
        if let refresh, !refresh.isEmpty {
            KeychainStore.set(refresh, for: KeychainStore.Keys.googleRefreshToken)
        }
        let expiry = Date.now.addingTimeInterval(expiresIn).timeIntervalSince1970
        KeychainStore.set(String(expiry), for: KeychainStore.Keys.googleTokenExpiry)
    }

    private func clearTokens() {
        KeychainStore.remove(KeychainStore.Keys.googleAccessToken)
        KeychainStore.remove(KeychainStore.Keys.googleRefreshToken)
        KeychainStore.remove(KeychainStore.Keys.googleTokenExpiry)
    }

    // MARK: - HTTP

    private func postForm(_ url: URL, _ fields: [String: String]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = fields
            .map { "\($0.key)=\(formEncode($0.value))" }
            .joined(separator: "&")
            .data(using: .utf8)

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            return data
        } catch let error as CancellationError {
            throw error
        } catch {
            throw AuthError("Couldn't reach Google. Check the watch's connection.")
        }
    }

    private func oauthErrorMessage(in data: Data) -> String? {
        let reply = try? JSONDecoder().decode(TokenResponse.self, from: data)
        return reply?.errorDescription ?? reply?.error
    }
}

// MARK: - Wire formats

private struct DeviceGrant: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationURL: String
    let expiresIn: Double
    let interval: Double?

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationURL = "verification_url"
        case expiresIn = "expires_in"
        case interval
    }
}

private struct TokenResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Double?
    let error: String?
    let errorDescription: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case error
        case errorDescription = "error_description"
    }
}

private struct AuthError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

private func formEncode(_ value: String) -> String {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
}
