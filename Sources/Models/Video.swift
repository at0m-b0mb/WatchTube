import Foundation

/// A single YouTube video as shown in search results.
///
/// Kept deliberately small — the watch screen only needs a thumbnail,
/// a title, the channel name, and an optional duration label.
struct Video: Identifiable, Hashable {
    let id: String              // the YouTube videoId, e.g. "dQw4w9WgXcQ"
    let title: String
    let channelTitle: String
    let thumbnailURL: URL?
    let lengthText: String?     // human label like "4:13" when available

    /// The canonical watch URL — handy for "open on iPhone" handoff later.
    var watchURL: URL? {
        URL(string: "https://www.youtube.com/watch?v=\(id)")
    }
}
