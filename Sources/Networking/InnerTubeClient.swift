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

    /// One resolution attempt: which client, and whether to attach the Google
    /// bearer token. Keyless attempts come first and are the proven path —
    /// signing in only ever *appends* an authenticated attempt, so it can help
    /// (age-restricted videos the account can reach) but can never break the
    /// keyless playback that already works.
    private struct Attempt { let client: PlayerClient; let useAuth: Bool }

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

    // MARK: - Suggestions (as-you-type autocomplete)

    /// Live query completions from YouTube's public suggest service. Returns an
    /// empty list on any hiccup — suggestions are a nicety, never load-bearing.
    func suggestions(for query: String) async -> [String] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        var components = URLComponents(string: "https://suggestqueries-clients6.youtube.com/complete/search")!
        components.queryItems = [
            URLQueryItem(name: "client", value: "youtube"),
            URLQueryItem(name: "ds", value: "yt"),
            URLQueryItem(name: "hl", value: language),
            URLQueryItem(name: "q", value: trimmed)
        ]
        guard let url = components.url else { return [] }
        var request = URLRequest(url: url)
        request.setValue(webUserAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, _) = try? await URLSession.shared.data(for: request),
              var text = String(data: data, encoding: .utf8) else { return [] }

        // Response is JSONP: window.google.ac.h([ "q", [["term",0,[…]], …] ])
        guard let open = text.firstIndex(of: "("),
              let close = text.lastIndex(of: ")") else { return [] }
        text = String(text[text.index(after: open)..<close])
        guard let json = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [Any],
              json.count > 1, let rows = json[1] as? [[Any]] else { return [] }
        return rows.compactMap { $0.first as? String }
    }

    // MARK: - Related / Up Next

    /// Videos YouTube suggests alongside `videoId` (the watch-next rail). Modern
    /// responses use `lockupViewModel`; our parser handles both that and the
    /// legacy renderers.
    func relatedVideos(to videoId: String) async throws -> [Video] {
        let data = try await post(path: "next",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "videoId": videoId])
        var videos = try parseVideos(from: data)
        videos.removeAll { $0.id == videoId }   // drop the video we're watching
        return videos
    }

    // MARK: - Shorts

    /// A shelf of Shorts for `query` (defaults to a broad, always-populated
    /// term). Parses only `shortsLockupViewModel` nodes, flagged `isShort`.
    func shorts(query: String = "shorts") async throws -> [Video] {
        let data = try await post(path: "search",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "query": query])
        let videos = extractVideos(from: try jsonRoot(data), mode: .shortsOnly)
        if videos.isEmpty { throw APIError.empty }
        return videos
    }

    // MARK: - Channel

    /// A channel's uploads (browse the channel id, Videos tab). `channelId` is
    /// the `UC…` value carried on search results.
    func channelVideos(channelId: String) async throws -> [Video] {
        let data = try await post(path: "browse",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext,
                                         "browseId": channelId,
                                         "params": "EgZ2aWRlb3PyBgQKAjoA"])  // "Videos" tab
        let videos = try parseVideos(from: data)
        if videos.isEmpty { throw APIError.empty }
        return videos
    }

    // MARK: - Account feeds (require Google sign-in)

    /// An authenticated browse feed (subscriptions / liked / watch later).
    /// These ride the Google bearer token, which Google has restricted for
    /// InnerTube — so they may legitimately come back empty even when signed
    /// in. Callers should present that as an honest "couldn't load", not a bug.
    func accountFeed(_ feed: AccountFeed) async throws -> [Video] {
        guard authorization != nil else { throw APIError.notPlayable("Sign in with Google first.") }
        let data = try await post(path: "browse",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  authorization: authorization,
                                  body: ["context": webContext, "browseId": feed.browseId])
        let videos = extractVideos(from: try jsonRoot(data), mode: .all)
        if videos.isEmpty { throw APIError.empty }
        return videos
    }

    enum AccountFeed {
        case subscriptions, liked, watchLater
        var browseId: String {
            switch self {
            case .subscriptions: "FEsubscriptions"
            case .liked: "VLLL"
            case .watchLater: "VLWL"
            }
        }
    }

    // MARK: - Comments

    func comments(videoId: String) async throws -> [Comment] {
        let data = try await post(path: "next",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "videoId": videoId])
        let root = try jsonRoot(data)
        return extractComments(from: root)
    }

    private func extractComments(from root: Any) -> [Comment] {
        var results: [Comment] = []
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if let renderer = dict["commentRenderer"] as? [String: Any] {
                    if let comment = mapComment(renderer) { results.append(comment) }
                }
                if results.count >= 20 { return }
                for value in dict.values { walk(value); if results.count >= 20 { return } }
            } else if let array = node as? [Any] {
                for value in array { walk(value); if results.count >= 20 { return } }
            }
        }
        walk(root)
        return results
    }

    private func mapComment(_ renderer: [String: Any]) -> Comment? {
        guard let id = renderer["commentId"] as? String else { return nil }
        let author = text(renderer["authorText"]) ?? "Unknown"
        let body = text(renderer["contentText"]) ?? ""
        guard !body.isEmpty else { return nil }
        let likes = text(renderer["voteCount"])
        let published = text(renderer["publishedTimeText"])
        let avatarURL: URL? = {
            guard let thumbs = (renderer["authorThumbnail"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
                  let urlStr = thumbs.first?["url"] as? String else { return nil }
            let full = urlStr.hasPrefix("//") ? "https:\(urlStr)" : urlStr
            return URL(string: full)
        }()
        let hearted = renderer["creatorHeart"] != nil
            || (renderer["actionButtons"] as? [String: Any])?["commentActionButtonsRenderer"] != nil
                && renderer["isHearted"] as? Bool == true
        return Comment(id: id, author: author, authorAvatarURL: avatarURL,
                       text: body, likeCount: likes, publishedText: published, isHearted: hearted)
    }

    // MARK: - Video description + details

    struct VideoDetail {
        let description: String
        let likeCount: String?
        let dateText: String?
        let subscriberCount: String?
    }

    func videoDetails(videoId: String) async throws -> VideoDetail {
        let data = try await post(path: "next",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "videoId": videoId])
        let root = try jsonRoot(data) as? [String: Any] ?? [:]
        return extractVideoDetail(from: root)
    }

    private func extractVideoDetail(from root: [String: Any]) -> VideoDetail {
        var desc = ""
        var likes: String?
        var dateText: String?
        var subCount: String?

        func walk(_ node: Any) {
            guard let dict = node as? [String: Any] else {
                if let arr = node as? [Any] { for v in arr { walk(v) } }
                return
            }
            if let structured = dict["structuredDescriptionContentRenderer"] as? [String: Any],
               let items = structured["items"] as? [[String: Any]] {
                for item in items {
                    if let descRenderer = item["expandableVideoDescriptionBodyRenderer"] as? [String: Any] {
                        desc = text(descRenderer["descriptionBodyText"]) ?? text(descRenderer["attributedDescriptionBodyText"]) ?? ""
                    } else if let videoDesc = item["videoDescriptionHeaderRenderer"] as? [String: Any] {
                        dateText = text(videoDesc["publishDate"]) ?? text(videoDesc["factoid"])
                        likes = text(videoDesc["views"])
                    }
                }
            }
            if let vps = dict["videoPrimaryInfoRenderer"] as? [String: Any] {
                dateText = dateText ?? text(vps["dateText"])
                if let sentimentBar = vps["sentimentBar"] as? [String: Any],
                   let sbr = sentimentBar["sentimentBarRenderer"] as? [String: Any] {
                    likes = text(sbr["tooltip"])
                }
            }
            if let vsi = dict["videoSecondaryInfoRenderer"] as? [String: Any] {
                if desc.isEmpty { desc = text(vsi["description"]) ?? "" }
                if let owner = vsi["owner"] as? [String: Any],
                   let ownerRend = owner["videoOwnerRenderer"] as? [String: Any] {
                    subCount = text(ownerRend["subscriberCountText"])
                }
            }
            for v in dict.values { walk(v) }
        }
        walk(root)
        return VideoDetail(description: desc, likeCount: likes, dateText: dateText, subscriberCount: subCount)
    }

    // MARK: - Channel header

    struct ChannelHeader {
        let avatarURL: URL?
        let subscriberCount: String?
        let videoCount: String?
        let description: String?
        let bannerURL: URL?
    }

    func channelHeader(channelId: String) async throws -> ChannelHeader {
        let data = try await post(path: "browse",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "browseId": channelId])
        let root = try jsonRoot(data) as? [String: Any] ?? [:]
        return extractChannelHeader(from: root)
    }

    private func extractChannelHeader(from root: [String: Any]) -> ChannelHeader {
        var avatar: URL?
        var subs: String?
        var videoCount: String?
        var desc: String?
        var banner: URL?

        func walk(_ node: Any) {
            guard let dict = node as? [String: Any] else {
                if let arr = node as? [Any] { for v in arr { walk(v) } }
                return
            }
            if let header = dict["c4TabbedHeaderRenderer"] as? [String: Any] {
                if let thumbs = (header["avatar"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
                   let url = thumbs.last?["url"] as? String {
                    avatar = URL(string: url.hasPrefix("//") ? "https:\(url)" : url)
                }
                subs = text(header["subscriberCountText"])
                videoCount = text(header["videosCountText"])
                if let bannerImg = (header["banner"] as? [String: Any])?["thumbnails"] as? [[String: Any]],
                   let bUrl = bannerImg.last?["url"] as? String {
                    banner = URL(string: bUrl.hasPrefix("//") ? "https:\(bUrl)" : bUrl)
                }
            }
            if let pageHeader = dict["pageHeaderRenderer"] as? [String: Any] {
                if let content = pageHeader["content"] as? [String: Any],
                   let pageVM = content["pageHeaderViewModel"] as? [String: Any] {
                    if let img = (pageVM["image"] as? [String: Any])?["decoratedAvatarViewModel"] as? [String: Any],
                       let avatarVM = img["avatar"] as? [String: Any],
                       let avatarImg = (avatarVM["avatarViewModel"] as? [String: Any])?["image"] as? [String: Any],
                       let sources = avatarImg["sources"] as? [[String: Any]],
                       let url = sources.last?["url"] as? String {
                        avatar = URL(string: url.hasPrefix("//") ? "https:\(url)" : url)
                    }
                    if let meta = pageVM["metadata"] as? [String: Any],
                       let contentMeta = meta["contentMetadataViewModel"] as? [String: Any],
                       let rows = contentMeta["metadataRows"] as? [[String: Any]] {
                        for row in rows {
                            guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
                            for part in parts {
                                guard let t = (part["text"] as? [String: Any])?["content"] as? String else { continue }
                                if t.lowercased().contains("subscriber") { subs = t }
                                else if t.lowercased().contains("video") { videoCount = t }
                            }
                        }
                    }
                    if let descNode = pageVM["description"] as? [String: Any] {
                        desc = (descNode["descriptionPreviewViewModel"] as? [String: Any])
                            .flatMap { ($0["description"] as? [String: Any])?["content"] as? String }
                            ?? descNode["content"] as? String
                    }
                }
            }
            if let aboutRenderer = dict["channelAboutFullMetadataRenderer"] as? [String: Any] {
                desc = desc ?? text(aboutRenderer["description"])
            }
            for v in dict.values { walk(v) }
        }
        walk(root)
        return ChannelHeader(avatarURL: avatar, subscriberCount: subs, videoCount: videoCount,
                             description: desc, bannerURL: banner)
    }

    // MARK: - Playlists

    func playlistVideos(playlistId: String) async throws -> [Video] {
        let data = try await post(path: "browse",
                                  apiKey: Self.webKey,
                                  userAgent: webUserAgent,
                                  body: ["context": webContext, "browseId": "VL\(playlistId)"])
        let videos = try parseVideos(from: data)
        if videos.isEmpty { throw APIError.empty }
        return videos
    }

    private var webContext: [String: Any] {
        ["client": ["clientName": "WEB", "clientVersion": webClientVersion,
                    "hl": language, "gl": region]]
    }

    private func jsonRoot(_ data: Data) throws -> Any {
        guard let root = try? JSONSerialization.jsonObject(with: data) else {
            throw APIError.decoding("response root")
        }
        return root
    }

    private func parseVideos(from data: Data) throws -> [Video] {
        extractVideos(from: try jsonRoot(data), mode: .videosOnly)
    }

    // MARK: - Stream resolution

    func resolveStream(videoId: String) async throws -> StreamResolution {
        var resolver = self
        // Fresh visitorData clears soft bot-gating for the keyless clients and
        // is harmless when signed in, so we always try to grab one.
        if resolver.visitorData?.isEmpty ?? true {
            resolver.visitorData = await Self.fetchVisitorData()   // best effort
        }

        // Proven keyless path first: IOS hands back an HLS manifest (ideal for
        // the watch — native AVPlayer, adaptive, audio+video), ANDROID_VR is the
        // least-gated keyless client, TVHTML5 backstops. Only after those do we
        // add an authenticated TV attempt (when signed in) for account-gated
        // content — so sign-in can only ever help, never break what works.
        var attempts: [Attempt] = [
            Attempt(client: .ios, useAuth: false),
            Attempt(client: .androidVR, useAuth: false),
            Attempt(client: .tvhtml5, useAuth: false)
        ]
        if authorization != nil {
            attempts.append(Attempt(client: .tvhtml5, useAuth: true))
        }

        var authStatus: String?
        var fallbackReason = "No watch-playable stream found for this video."
        for attempt in attempts {
            switch await resolver.attempt(videoId: videoId,
                                          client: attempt.client,
                                          useAuth: attempt.useAuth) {
            case .ok(let resolution):
                return resolution
            case .needsAuth(let status):
                authStatus = status
            case .noStream:
                break
            case .httpError(let code):
                fallbackReason = "YouTube rejected the \(attempt.client.clientName) request (HTTP \(code)). "
                    + "The client may need updating."
            }
        }

        // Every client we tried (keyless and, if signed in, authenticated)
        // came back gated. Surface the most actionable next step.
        if let status = authStatus {
            throw APIError.loginRequired(
                "YouTube is gating this video (\(status)). It may be age-restricted "
                + "or your network is being bot-checked — try another video, or add a "
                + "PoToken in Settings → Advanced.")
        }
        throw APIError.notPlayable(fallbackReason)
    }

    private enum ResolveOutcome {
        case ok(StreamResolution)
        case needsAuth(String)
        case noStream
        case httpError(Int)
    }

    private func attempt(videoId: String, client: PlayerClient, useAuth: Bool) async -> ResolveOutcome {
        // The Google token is a TV-client OAuth token, so it's only ever
        // attached to a TVHTML5 attempt the caller explicitly flagged.
        let bearer = useAuth ? authorization : nil

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

    // MARK: - JSON walking
    //
    // InnerTube JSON is deeply nested and shifts between layouts (and now mixes
    // legacy *Renderer nodes with newer *ViewModel nodes), so we recursively
    // gather every known video-bearing node instead of hard-coding a path.

    private enum ExtractMode {
        case videosOnly   // regular videos + lockup videos, no Shorts
        case shortsOnly   // only Shorts
        case all          // everything (used for account feeds)
    }

    private func extractVideos(from root: Any, mode: ExtractMode) -> [Video] {
        var seen = Set<String>()
        var out: [Video] = []
        func add(_ video: Video?) {
            guard let video, !seen.contains(video.id) else { return }
            seen.insert(video.id)
            out.append(video)
        }
        func walk(_ node: Any) {
            if let dict = node as? [String: Any] {
                if mode != .shortsOnly {
                    for key in ["videoRenderer", "gridVideoRenderer", "compactVideoRenderer"] {
                        if let renderer = dict[key] as? [String: Any] { add(mapVideoRenderer(renderer)) }
                    }
                    if let lockup = dict["lockupViewModel"] as? [String: Any] { add(mapLockup(lockup)) }
                }
                if mode != .videosOnly, let short = dict["shortsLockupViewModel"] as? [String: Any] {
                    add(mapShortsLockup(short))
                }
                for value in dict.values { walk(value) }
            } else if let array = node as? [Any] {
                for value in array { walk(value) }
            }
        }
        walk(root)
        return out
    }

    private func mapVideoRenderer(_ renderer: [String: Any]) -> Video? {
        guard let id = renderer["videoId"] as? String else { return nil }
        let title = text(renderer["title"]) ?? "Untitled"
        let channel = text(renderer["ownerText"])
            ?? text(renderer["longBylineText"])
            ?? text(renderer["shortBylineText"])
            ?? ""
        let views = text(renderer["shortViewCountText"]) ?? text(renderer["viewCountText"])
        let published = text(renderer["publishedTimeText"])
        let avatar = channelAvatarURL(in: renderer)
        return Video(
            id: id,
            title: title,
            channelTitle: channel,
            thumbnailURL: Video.thumbnailURL(forVideoId: id),
            lengthText: text(renderer["lengthText"]),
            channelId: channelId(in: renderer),
            viewCount: views,
            channelAvatarURL: avatar,
            publishedText: published
        )
    }

    private func mapLockup(_ vm: [String: Any]) -> Video? {
        guard (vm["contentType"] as? String) == "LOCKUP_CONTENT_TYPE_VIDEO",
              let id = vm["contentId"] as? String else { return nil }
        let metadata = (vm["metadata"] as? [String: Any])?["lockupMetadataViewModel"] as? [String: Any]
        let title = (metadata?["title"] as? [String: Any])?["content"] as? String ?? "Untitled"

        let thumb = Video.thumbnailURL(forVideoId: id)
        let parsed = lockupMetadataTexts(metadata)
        let duration = lockupDuration(vm)
        let avatar = lockupAvatarURL(metadata)

        return Video(
            id: id,
            title: title,
            channelTitle: parsed.channel,
            thumbnailURL: thumb,
            lengthText: duration,
            viewCount: parsed.views,
            channelAvatarURL: avatar,
            publishedText: parsed.published
        )
    }

    private struct LockupMeta {
        var channel = ""
        var views: String?
        var published: String?
    }

    private func lockupMetadataTexts(_ metadata: [String: Any]?) -> LockupMeta {
        guard let meta = metadata?["metadata"] as? [String: Any],
              let content = meta["contentMetadataViewModel"] as? [String: Any],
              let rows = content["metadataRows"] as? [[String: Any]] else { return LockupMeta() }
        var result = LockupMeta()
        for row in rows {
            guard let parts = row["metadataParts"] as? [[String: Any]] else { continue }
            for part in parts {
                guard let t = (part["text"] as? [String: Any])?["content"] as? String else { continue }
                if result.channel.isEmpty { result.channel = t }
                else if result.views == nil, t.lowercased().contains("view") { result.views = t }
                else if result.published == nil, t.lowercased().contains("ago") { result.published = t }
            }
        }
        return result
    }

    private func lockupAvatarURL(_ metadata: [String: Any]?) -> URL? {
        guard let avatar = metadata?["image"] as? [String: Any] else { return nil }
        if let sources = avatar["sources"] as? [[String: Any]],
           let urlStr = sources.first?["url"] as? String {
            let full = urlStr.hasPrefix("//") ? "https:\(urlStr)" : urlStr
            return URL(string: full)
        }
        return nil
    }

    private func lockupDuration(_ vm: [String: Any]) -> String? {
        guard let contentImage = vm["contentImage"] as? [String: Any] else { return nil }
        func findBadge(_ node: Any) -> String? {
            if let dict = node as? [String: Any] {
                if let badge = dict["thumbnailBadgeViewModel"] as? [String: Any],
                   let t = badge["text"] as? String, t.contains(":") { return t }
                for v in dict.values { if let r = findBadge(v) { return r } }
            } else if let arr = node as? [Any] {
                for v in arr { if let r = findBadge(v) { return r } }
            }
            return nil
        }
        return findBadge(contentImage)
    }

    /// A Short card. The videoId lives under the reel-watch endpoint; the title
    /// is recovered from the accessibility string ("Title, N views - play Short").
    private func mapShortsLockup(_ vm: [String: Any]) -> Video? {
        let command = (vm["onTap"] as? [String: Any])?["innertubeCommand"] as? [String: Any]
        let reel = command?["reelWatchEndpoint"] as? [String: Any]
        guard let id = reel?["videoId"] as? String else { return nil }
        var title = "Short"
        if let a11y = vm["accessibilityText"] as? String {
            title = a11y
                .replacingOccurrences(of: " - play Short", with: "")
            if let range = title.range(of: #", [\d,.]+ ?[KMB]? ?(thousand|million|billion)? ?views?$"#,
                                       options: .regularExpression) {
                title.removeSubrange(range)
            }
        }
        return Video(
            id: id,
            title: title,
            channelTitle: "",
            thumbnailURL: Video.thumbnailURL(forVideoId: id),
            lengthText: nil,
            isShort: true
        )
    }

    private func channelAvatarURL(in renderer: [String: Any]) -> URL? {
        let thumbs = (renderer["channelThumbnailSupportedRenderers"] as? [String: Any])
            .flatMap { $0["channelThumbnailWithLinkRenderer"] as? [String: Any] }
            .flatMap { $0["thumbnail"] as? [String: Any] }
            .flatMap { $0["thumbnails"] as? [[String: Any]] }
        ?? (renderer["channelThumbnail"] as? [String: Any])
            .flatMap { $0["thumbnails"] as? [[String: Any]] }
        guard let url = thumbs?.first?["url"] as? String else { return nil }
        let full = url.hasPrefix("//") ? "https:\(url)" : url
        return URL(string: full)
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

    /// Pulls the channel's `UC…` id out of a renderer's byline navigation
    /// endpoint, so a tap can open that channel's page.
    private func channelId(in renderer: [String: Any]) -> String? {
        for key in ["longBylineText", "shortBylineText", "ownerText"] {
            guard let runs = (renderer[key] as? [String: Any])?["runs"] as? [[String: Any]] else { continue }
            for run in runs {
                if let browseId = (((run["navigationEndpoint"] as? [String: Any])?["browseEndpoint"]) as? [String: Any])?["browseId"] as? String,
                   browseId.hasPrefix("UC") {
                    return browseId
                }
            }
        }
        return nil
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

    /// iOS client — hands back a ready-to-play HLS manifest (adaptive,
    /// audio+video muxed), which is the ideal format for the watch. Tried
    /// first. Bump clientVersion + userAgent together when it breaks.
    static let ios = PlayerClient(
        clientName: "IOS",
        clientVersion: "20.10.4",
        extraContext: [
            "deviceMake": "Apple", "deviceModel": "iPhone16,2",
            "osName": "iPhone", "osVersion": "18.3.2.22D82", "utcOffsetMinutes": 0
        ],
        userAgent: "com.google.ios.youtube/20.10.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)",
        apiKey: "AIzaSyB-63vPrdThhKuerbB2N_l7Kwwcxj6yUAc"
    )

    /// Quest VR client — keyless, historically the least PoToken-gated client,
    /// so it backstops iOS. Returns a direct muxed progressive URL (itag 18).
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
        apiKey: nil
    )

    /// PlayStation/TV client — the one client the Google TV OAuth token is
    /// valid for, so it carries the authenticated attempt for account-gated
    /// (e.g. age-restricted) videos when signed in.
    static let tvhtml5 = PlayerClient(
        clientName: "TVHTML5",
        clientVersion: "7.20250120.19.00",
        extraContext: [:],
        userAgent: "Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko)",
        apiKey: "AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8"
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
