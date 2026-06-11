import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  InnerTubeClient — the extraction layer (THE BRITTLE PART)
// ─────────────────────────────────────────────────────────────────────────────
//
//  Talks to YouTube's internal "InnerTube" API (the endpoints the official apps
//  use). No API key to create — that's why WatchTube is keyless and "free for
//  anyone."
//
//    • search(query:)          -> WEB client, returns clean videoRenderers
//    • resolveStream(videoId:) -> tries TVHTML5 → IOS → ANDROID_VR, returning
//                                 the first that yields an HLS (.m3u8) manifest
//                                 or a direct progressive URL AVPlayer can play.
//
//  Authentication (all optional, in order of niceness):
//    1. Google sign-in (GoogleAuth) — a bearer token is attached to player
//       requests on the clients that accept it, so YouTube treats playback as
//       your account and skips the bot wall.
//    2. PoToken + visitorData pasted in Settings → Advanced.
//    3. Nothing — fully keyless; ANDROID_VR is the least-gated keyless client.
//
//  ⚠️  THIS IS WHAT BREAKS WHEN YOUTUBE CHANGES THINGS.
//      The knobs to refresh live in `playbackClients` and `webClientVersion`.
//
//  Keys below are public values shipped inside YouTube's own clients — not
//  secrets, not tied to you.
// ─────────────────────────────────────────────────────────────────────────────

struct InnerTubeClient {
    var language = "en"
    var region = "US"
    var poToken: String? = nil
    var visitorData: String? = nil
    /// Google OAuth access token (set when the user signed in). Only attached
    /// to player requests — search stays keyless so it can never break from an
    /// expired token.
    var authorization: String? = nil
    /// Mirrors the Data Saver toggle: lowers the progressive-quality cap.
    var dataSaver = false

    /// Hitting www.youtube.com (not the youtubei.googleapis.com gateway, which
    /// rejects player calls with FAILED_PRECONDITION).
    private let base = "https://www.youtube.com/youtubei/v1/"

    private static let webKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    private let webClientVersion = "2.20241205.01.00"
    private let webUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        + "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"

    /// Clients tried, in order, when resolving a stream. TVHTML5 and IOS accept
    /// the Google bearer token and stream via HLS; ANDROID_VR is keyless-only
    /// but historically the least bot-gated, so it backstops everything.
    private static let playbackClients: [PlayerClient] = [.tvhtml5, .ios, .androidVR]

    // MARK: - Search

    func search(query: String) async throws -> [Video] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let data = try await post(path: "search",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "query": trimmed])
        let videos = try parseVideos(from: data)
        if videos.isEmpty { throw APIError.empty }
        return videos
    }

    /// Home/Trending feed (browse `FEtrending`). Best-effort — callers should
    /// fall back to a default search if this comes back empty or gated.
    func trending() async throws -> [Video] {
        let data = try await post(path: "browse",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "browseId": "FEtrending"])
        let videos = try parseVideos(from: data)
        if videos.isEmpty { throw APIError.empty }
        return videos
    }

    private var webContext: [String: Any] {
        ["client": ["clientName": "WEB", "clientVersion": webClientVersion,
                    "hl": language, "gl": region]]
    }

    private func parseVideos(from data: Data) throws -> [Video] {
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding("response root")
        }
        var renderers: [[String: Any]] = []
        collectVideoRenderers(in: root, into: &renderers)

        var seen = Set<String>()
        var videos: [Video] = []
        for renderer in renderers {
            guard let video = mapVideoRenderer(renderer), !seen.contains(video.id) else { continue }
            seen.insert(video.id)
            videos.append(video)
        }
        return videos
    }

    // MARK: - Stream resolution

    func resolveStream(videoId: String) async throws -> StreamResolution {
        var resolver = self
        // Fresh visitorData clears soft gating for keyless requests; it's
        // skipped entirely when signed in (the account identity replaces it).
        if resolver.authorization == nil, resolver.visitorData?.isEmpty ?? true {
            resolver.visitorData = await Self.fetchVisitorData()   // best effort
        }

        var authStatus: String?
        var fallbackReason = "No watch-playable stream found for this video."
        for client in Self.playbackClients {
            switch await resolver.attempt(videoId: videoId, client: client) {
            case .ok(let resolution):
                return resolution
            case .needsAuth(let status):
                authStatus = status
            case .noStream:
                break
            case .httpError(let code):
                fallbackReason = "YouTube rejected the \(client.clientName) request (HTTP \(code)). "
                    + "The client may need updating."
            }
        }

        // A verification prompt is the most actionable thing to surface, so it
        // wins over a generic HTTP error from another client.
        if let status = authStatus {
            if authorization == nil {
                throw APIError.loginRequired(
                    "YouTube wants verification for this video (\(status)). "
                    + "Sign in with Google in Settings — or add a PoToken under Advanced.")
            }
            throw APIError.notPlayable(
                "YouTube refused this video even while signed in (\(status)). Try another video.")
        }
        throw APIError.notPlayable(fallbackReason)
    }

    private enum ResolveOutcome {
        case ok(StreamResolution)
        case needsAuth(String)
        case noStream
        case httpError(Int)
    }

    private func attempt(videoId: String, client: PlayerClient) async -> ResolveOutcome {
        // Bearer tokens come from YouTube's TV OAuth client, so only the
        // TV/iOS-family clients accept them; ANDROID_VR always goes keyless.
        let bearer = client.supportsAuth ? authorization : nil

        var body: [String: Any] = [
            "context": ["client": clientContext(for: client, authenticated: bearer != nil)],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        // PoToken is bound to visitorData; both are replaced by the account
        // identity when a bearer token is attached.
        if bearer == nil, let poToken, !poToken.isEmpty {
            body["serviceIntegrityDimensions"] = ["poToken": poToken]
        }

        let data: Data
        do {
            data = try await post(path: "player",
                                  apiKey: client.apiKey,
                                  userAgent: client.userAgent,
                                  authorization: bearer,
                                  body: body)
        } catch let APIError.badResponse(code) {
            return .httpError(code)
        } catch {
            return .httpError(-1)
        }

        guard let resp = try? JSONDecoder().decode(PlayerResponse.self, from: data) else {
            return .noStream
        }
        if let status = resp.playabilityStatus?.status, status != "OK" {
            return .needsAuth(status)
        }

        let title = resp.videoDetails?.title ?? "Video"
        let author = resp.videoDetails?.author ?? ""

        if let hls = resp.streamingData?.hlsManifestUrl, let url = URL(string: hls) {
            return .ok(StreamResolution(url: url, kind: .hls, title: title, author: author))
        }
        if let progressive = bestProgressiveURL(resp.streamingData?.formats),
           let url = URL(string: progressive) {
            return .ok(StreamResolution(url: url, kind: .progressive, title: title, author: author))
        }
        return .noStream
    }

    private func clientContext(for client: PlayerClient, authenticated: Bool) -> [String: Any] {
        var dict: [String: Any] = [
            "clientName": client.clientName,
            "clientVersion": client.clientVersion,
            "hl": language,
            "gl": region
        ]
        dict.merge(client.extraContext) { _, new in new }
        if !authenticated, let visitorData, !visitorData.isEmpty {
            dict["visitorData"] = visitorData
        }
        return dict
    }

    // MARK: - Networking

    private func post(path: String,
                      apiKey: String?,
                      userAgent: String,
                      authorization: String? = nil,
                      body: [String: Any]) async throws -> Data {
        var components = URLComponents(string: base + path)!
        var query = [URLQueryItem(name: "prettyPrint", value: "false")]
        // The static key is dropped when a bearer token rides along — modern
        // InnerTube doesn't need it, and key+OAuth together can trip refusals.
        if let apiKey, authorization == nil {
            query.insert(URLQueryItem(name: "key", value: apiKey), at: 0)
        }
        components.queryItems = query

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("2", forHTTPHeaderField: "X-Goog-Api-Format-Version")
        if let authorization {
            request.setValue("Bearer \(authorization)", forHTTPHeaderField: "Authorization")
        } else if let visitorData, !visitorData.isEmpty {
            request.setValue(visitorData, forHTTPHeaderField: "X-Goog-Visitor-Id")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.network("No response from server.")
            }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.badResponse(http.statusCode)
            }
            return data
        } catch let error as APIError {
            throw error
        } catch {
            throw APIError.network(error.localizedDescription)
        }
    }

    /// Best-effort grab of a `visitorData` token from the YouTube home page.
    /// Helps clear soft bot-gating; harmless if it fails.
    private static func fetchVisitorData() async -> String? {
        var request = URLRequest(url: URL(string: "https://www.youtube.com/")!)
        request.setValue(
            "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
            + "(KHTML, like Gecko) Chrome/120.0 Safari/537.36",
            forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let html = String(data: data, encoding: .utf8),
              let start = html.range(of: "\"visitorData\":\"") else { return nil }
        let rest = html[start.upperBound...]
        guard let end = rest.range(of: "\"") else { return nil }
        let token = String(rest[..<end.lowerBound])
        return token.isEmpty ? nil : token
    }

    // MARK: - Search JSON walking
    //
    // InnerTube search JSON is deeply nested and shifts between layouts, so we
    // recursively gather every `videoRenderer` instead of hard-coding a path.

    private func collectVideoRenderers(in node: Any, into result: inout [[String: Any]]) {
        if let dict = node as? [String: Any] {
            for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer"] {
                if let renderer = dict[key] as? [String: Any] {
                    result.append(renderer)
                }
            }
            for value in dict.values {
                collectVideoRenderers(in: value, into: &result)
            }
        } else if let array = node as? [Any] {
            for value in array {
                collectVideoRenderers(in: value, into: &result)
            }
        }
    }

    private func mapVideoRenderer(_ renderer: [String: Any]) -> Video? {
        guard let id = renderer["videoId"] as? String else { return nil }
        let title = text(renderer["title"]) ?? "Untitled"
        let channel = text(renderer["ownerText"])
            ?? text(renderer["longBylineText"])
            ?? text(renderer["shortBylineText"])
            ?? ""
        return Video(
            id: id,
            title: title,
            channelTitle: channel,
            thumbnailURL: thumbnailURL(in: renderer),
            lengthText: text(renderer["lengthText"])
        )
    }

    private func text(_ node: Any?) -> String? {
        guard let node = node as? [String: Any] else { return nil }
        if let simple = node["simpleText"] as? String { return simple }
        if let runs = node["runs"] as? [[String: Any]] {
            let joined = runs.compactMap { $0["text"] as? String }.joined()
            return joined.isEmpty ? nil : joined
        }
        return nil
    }

    private func thumbnailURL(in renderer: [String: Any]) -> URL? {
        guard let thumbnail = renderer["thumbnail"] as? [String: Any],
              let thumbnails = thumbnail["thumbnails"] as? [[String: Any]],
              let best = thumbnails.last,
              let urlString = best["url"] as? String else { return nil }
        return URL(string: urlString)
    }

    /// The watch screen tops out well under 480p, so "best" means the sharpest
    /// stream at or below the cap (360p with Data Saver on), falling back to
    /// the smallest stream above it.
    private func bestProgressiveURL(_ formats: [PlayerResponse.Format]?) -> String? {
        guard let formats else { return nil }
        let playable = formats.filter { $0.url != nil }
        let cap = dataSaver ? 360 : 480
        let below = playable
            .filter { ($0.height ?? 0) <= cap }
            .max { ($0.height ?? 0) < ($1.height ?? 0) }
        let above = playable
            .min { ($0.height ?? .max) < ($1.height ?? .max) }
        return (below ?? above)?.url
    }
}

// MARK: - Client profiles

private struct PlayerClient {
    let clientName: String
    let clientVersion: String
    let extraContext: [String: Any]
    let userAgent: String
    let apiKey: String?
    /// Whether this client accepts the TV-client OAuth bearer token.
    let supportsAuth: Bool

    /// PlayStation/TV client — streams via HLS, lightest bot-gating, and the
    /// natural home for the TV OAuth token when signed in.
    static let tvhtml5 = PlayerClient(
        clientName: "TVHTML5",
        clientVersion: "7.20250120.19.00",
        extraContext: [:],
        userAgent: "Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko)",
        apiKey: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8",
        supportsAuth: true
    )

    /// iOS client — yields HLS where allowed. Bump version + userAgent together.
    static let ios = PlayerClient(
        clientName: "IOS",
        clientVersion: "20.10.4",
        extraContext: [
            "deviceMake": "Apple", "deviceModel": "iPhone16,2",
            "osName": "iPhone", "osVersion": "18.3.2.22D82", "utcOffsetMinutes": 0
        ],
        userAgent: "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
        apiKey: "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc",
        supportsAuth: true
    )

    /// Quest VR client — keyless-only, but historically the least PoToken-gated
    /// client, so it backstops the chain. Returns direct progressive URLs.
    static let androidVR = PlayerClient(
        clientName: "ANDROID_VR",
        clientVersion: "1.62.27",
        extraContext: [
            "deviceMake": "Oculus", "deviceModel": "Quest 3",
            "osName": "Android", "osVersion": "12L",
            "androidSdkVersion": 32, "utcOffsetMinutes": 0
        ],
        userAgent: "com.google.android.apps.youtube.vr.oculus/1.62.27 "
            + "(Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip",
        apiKey: nil,
        supportsAuth: false
    )
}

// MARK: - Player endpoint decoding

struct PlayerResponse: Decodable {
    let playabilityStatus: PlayabilityStatus?
    let streamingData: StreamingData?
    let videoDetails: VideoDetails?

    struct PlayabilityStatus: Decodable {
        let status: String?
        let reason: String?
    }
    struct StreamingData: Decodable {
        let hlsManifestUrl: String?
        let formats: [Format]?
        let adaptiveFormats: [Format]?
    }
    struct Format: Decodable {
        let itag: Int?
        let url: String?
        let mimeType: String?
        let qualityLabel: String?
        let height: Int?
        let width: Int?
        let audioQuality: String?
    }
    struct VideoDetails: Decodable {
        let videoId: String?
        let title: String?
        let author: String?
        let lengthSeconds: String?
    }
}
