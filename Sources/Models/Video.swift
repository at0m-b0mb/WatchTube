import Foundation

/// A single YouTube video as shown in search results.
///
/// Kept deliberately small — the watch screen only needs a thumbnail,
/// a title, the channel name, and an optional duration label.
struct Video: Identifiable, Hashable, Codable {
    let id: String              // the YouTube videoId, e.g. "dQw4w9WgXcQ"
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let lengthText: String?     // human label like "4:13" when available
    var channelId: String? = nil   // UC… id, when known — powers channel pages
    var isShort: Bool = false      // vertical Short, played full-screen
    var viewCount: String? = nil   // "1.2M views" when available
    var channelAvatarURL: URL? = nil
    var publishedText: String? = nil  // "2 days ago", "3 weeks ago"

    /// The canonical watch URL — handy for "open on iPhone" handoff later.
    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }

    /// A thumbnail that always exists — InnerTube's newer "viewModel" layouts
    /// don't always carry one, so we fall back to YouTube's canonical CDN path.
    static func thumbnailURL(forVideoId id: String) -> URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    }
}
