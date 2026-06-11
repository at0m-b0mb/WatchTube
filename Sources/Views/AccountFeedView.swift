import SwiftUI

/// One signed-in feed (subscriptions / liked / watch later), with an honest
/// empty state since these depend on YouTube sharing account data with a
/// non-official client.
struct AccountFeedView: View {
    @State private var model: AccountViewModel

    init(feed: AccountViewModel.Feed) {
        _model = State(initialValue: AccountViewModel(feed: feed))
    }

    var body: some View {
        List {
            Section {
                if model.isLoading && model.videos.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                } else if let error = model.errorMessage, model.videos.isEmpty {
                    EmptyStateRow(icon: "exclamationmark.icloud", text: error)
                } else {
                    ForEach(model.videos) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                }
            } header: {
                Label(model.feed.title, systemImage: model.feed.icon)
            }
        }
        .navigationTitle(model.feed.title)
        .navigationDestination(for: Video.self) { PlayerView(video: $0) }
        .navigationDestination(for: ChannelRef.self) { ChannelView(channel: $0) }
        .brandBackdrop()
        .onAppear { model.loadIfNeeded() }
        .refreshable { await model.reload() }
    }
}
