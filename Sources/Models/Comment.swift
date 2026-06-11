import Foundation

struct Comment: Identifiable {
    let id: String
    let author: String
    let authorAvatarURL: URL?
    let text: String
    let likeCount: String?
    let publishedText: String?
    let isHearted: Bool
}
