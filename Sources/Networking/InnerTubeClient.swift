import Foundation

// ─────────────────────────────────────────────────────────────────────────────
//  InnerTubeClient — the extraction layer (THE BRITTLE PART)
// ─────────────────────────────────────────────────────────────────────────────
//
//  Talks to YouTube's internal "InnerTube" API (the endpoints the official apps
//  use). No API key to create, no Google account — that's why WatchTube is
//  keyless and "free for anyone."
//
//    • search(query:)          -> WEB client, returns clean videoRenderers
//    • resolveStream(videoId:) -> tries TVHTML5 then IOS, returning the first
//                                 that yields an HLS (.m3u8) manifest AVPlayer
//                                 can play directly (audio + video).
//
//  ⚠️  THIS IS WHAT BREAKS WHEN YOUTUBE CHANGES THINGS.
//      YouTube actively gates stream resolution behind bot-detection. Depending
//      on your network and the day, a video may come back as LOGIN_REQUIRED —
//      that means YouTube wants a "Proof of Origin" token. Paste a PoToken +
//      visitorData in Settings → Advanced to get past it. The knobs to refresh
//      live in `playbackClients` and `webClientVersion` below.
//
//  Keys below are public values shipped inside YouTube's own clients — not
//  secrets, not tied to you.
// ─────────────────────────────────────────────────────────────────────────────

struct InnerTubeClient {
    var language = "en"
    var region = "US"
    var poToken: String? = nil
    var visitorData: String? = nil

    /// Hitting www.youtube.com (not the youtubei.googleapis.com gateway, which
    /// rejects player calls with FAILED_PRECONDITION).
    private let base = "https://www.youtube.com/youtubei/v1/"

    private static let webKey = "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    private let webClientVersion = "2.20241205.01.00"
    private let webUserAgent =
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        + "(KHTML, like Gecko) Chrome/120.0 Safari/537.36"

    /// Clients tried, in order, when resolving a stream. TVHTML5 streams via HLS
    /// and is the lightest-gated; IOS also yields HLS where it's allowed.
    private static let playbackClients: [PlayerClient] = [.tvhtml5, .ios]

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
        if resolver.visitorData?.isEmpty ?? true {
            resolver.visitorData = await Self.fetchVisitorData()   // best effort
        }

        var authReason: String? = nil
        var fallbackReason = "No watch-playable stream found for this video."
        for client in Self.playbackClients {
            switch await resolver.attempt(videoId: videoId, client: client) {
            case .ok(let resolution):
                return resolution
            case .needsAuth(let status):
                authReason = "YouTube wants verification for this video (\(status)). "
                    + "Try another video, or add a PoToken in Settings → Advanced."
            case .noStream:
                fallbackReason = "No watch-playable stream found for this video."
            case .httpError(let code):
                fallbackReason = "YouTube rejected the \(client.clientName) request (HTTP \(code)). "
                    + "The client may need updating."
            }
        }
        // A verification prompt is the most actionable thing to surface, so it
        // wins over a generic HTTP error from another client.
        throw APIError.notPlayable(authReason ?? fallbackReason)
    }

    private enum ResolveOutcome {
        case ok(StreamResolution)
        case needsAuth(String)
        case noStream
        case httpError(Int)
    }

    private func attempt(videoId: String, client: PlayerClient) async -> ResolveOutcome {
        var body: [String: Any] = [
            "context": ["client": clientContext(for: client)],
            "videoId": videoId,
            "contentCheckOk": true,
            "racyCheckOk": true
        ]
        if let poToken, !poToken.isEmpty {
            body["serviceIntegrityDimensions"] = ["poToken": poToken]
        }

        let data: Data
        do {
            data = try await post(path: "player",
                                  apiKey: client.apiKey,
                                  userAgent: client.userAgent,
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

    private func clientContext(for client: PlayerClient) -> [String: Any] {
        var dict: [String: Any] = [
            "clientName": client.clientName,
            "clientVersion": client.clientVersion,
            "hl": language,
            "gl": region
        ]
        dict.merge(client.extraContext) { _, new in new }
        if let visitorData, !visitorData.isEmpty { dict["visitorData"] = visitorData }
        return dict
    }

    // MARK: - Networking

    private func post(path: String, apiKey: String, userAgent: String, body: [String: Any]) async throws -> Data {
        var components = URLComponents(string: base + path)!
        components.queryItems = [
            URLQueryItem(name: "key", value: apiKey),
            URLQueryItem(name: "prettyPrint", value: "false")
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("2", forHTTPHeaderField: "X-Goog-Api-Format-Version")
        if let visitorData, !visitorData.isEmpty {
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

    private func bestProgressiveURL(_ formats: [PlayerResponse.Format]?) -> String? {
        guard let formats else { return nil }
        return formats
            .filter { $0.url != nil }
            .sorted { ($0.height ?? .max) < ($1.height ?? .max) }
            .first?
            .url
    }
}

// MARK: - Client profiles

private struct PlayerClient {
    let clientName: String
    let clientVersion: String
    let extraContext: [String: Any]
    let userAgent: String
    let apiKey: String

    /// PlayStation/TV client — streams via HLS, lightest bot-gating.
    static let tvhtml5 = PlayerClient(
        clientName: "TVHTML5",
        clientVersion: "7.20250120.19.00",
        extraContext: [:],
        userAgent: "Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko)",
        apiKey: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
    )

    /// iOS client — yields HLS where allowed. Bump version + userAgent together.
    static let ios = PlayerClient(
        clientName: "IOS",
        clientVersion: "19.45.4",
        extraContext: [
            "deviceMake": "Apple", "deviceModel": "iPhone16,2",
            "osName": "iPhone", "osVersion": "17.5.1.21F90", "utcOffsetMinutes": 0
        ],
        userAgent: "com.google.ios.youtube/19.45.4 (iPhone16,2; U; CPU iOS 17_5_1 like Mac OS X)",
        apiKey: "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc"
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
