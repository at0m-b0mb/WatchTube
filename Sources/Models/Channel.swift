import Foundation

struct ChannelRef: Identifiable, Hashable {
    let id: String
    let title: String
    var avatarURL: URL? = nil
    var subscriberCount: String? = nil
    var videoCount: String? = nil
    var description: String? = nil
}
