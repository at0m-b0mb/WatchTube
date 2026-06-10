import Foundation

/// The playable result of resolving a `videoId` through InnerTube.
///
/// We hand the `url` straight to `AVPlayer`. HLS is preferred because it is
/// adaptive (it scales quality to whatever bandwidth the watch has on
/// cellular/Wi-Fi) and `AVPlayer` plays it natively with audio + video.
struct StreamResolution {
    enum Kind {
        case hls          // an .m3u8 manifest — adaptive, preferred
        case progressive  // a single muxed MP4 carrying both audio and video
    }

    let url: URL
    let kind: Kind
    let title: String
    let author: String
}
