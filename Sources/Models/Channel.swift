import Foundation

/// A lightweight reference to a YouTube channel — just enough to open its page
/// and title it. Hashable so it can drive `navigationDestination`.
struct ChannelRef: Identifiable, Hashable {
    let id: String       // the channel's "UC…" id
    let title: String
}
