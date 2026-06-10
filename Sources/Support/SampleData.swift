import Foundation

/// Realistic sample videos used only to seed the simulator for screenshots
/// (launch with the `WT_SEED=1` environment variable). Real video IDs so the
/// thumbnails load; never used in normal operation.
enum SampleData {
    static let videos: [Video] = [
        Video(id: "5qap5aO4i9A", title: "lofi hip hop radio 💤 beats to sleep/chill to",
              channelTitle: "Lofi Girl", thumbnailURL: thumb("5qap5aO4i9A"), lengthText: "LIVE"),
        Video(id: "DWcJFNfaw9c", title: "Daft Punk - Harder, Better, Faster, Stronger",
              channelTitle: "Daft Punk", thumbnailURL: thumb("DWcJFNfaw9c"), lengthText: "3:45"),
        Video(id: "9bZkp7q19f0", title: "PSY - GANGNAM STYLE (강남스타일) M/V",
              channelTitle: "officialpsy", thumbnailURL: thumb("9bZkp7q19f0"), lengthText: "4:13"),
        Video(id: "dQw4w9WgXcQ", title: "Rick Astley - Never Gonna Give You Up",
              channelTitle: "Rick Astley", thumbnailURL: thumb("dQw4w9WgXcQ"), lengthText: "3:33"),
        Video(id: "kXYiU_JCYtU", title: "Linkin Park - Numb (Official Music Video)",
              channelTitle: "Linkin Park", thumbnailURL: thumb("kXYiU_JCYtU"), lengthText: "3:07"),
        Video(id: "jfKfPfyJRdk", title: "lofi hip hop radio 📚 beats to relax/study to",
              channelTitle: "Lofi Girl", thumbnailURL: thumb("jfKfPfyJRdk"), lengthText: "LIVE")
    ]

    static let searches = ["lofi hip hop", "apple watch ultra", "swiftui tutorial", "nasa live", "daft punk"]

    private static func thumb(_ id: String) -> URL? {
        URL(string: "https://i.ytimg.com/vi/\(id)/hqdefault.jpg")
    }
}
