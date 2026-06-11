import SwiftUI

/// A channel's page: its recent uploads. Reached by tapping a channel name.
struct ChannelView: View {
    let channel: ChannelRef
    @State private var model: ChannelViewModel

    init(channel: ChannelRef) {
        self.channel = channel
        _model = State(initialValue: ChannelViewModel(channelId: channel.id))
    }

    var body: some View {
        List {
            Section {
                if model.isLoading && model.videos.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
                } else if let error = model.errorMessage, model.videos.isEmpty {
                    EmptyStateRow(icon: "person.crop.circle.badge.exclamationmark", text: error)
                } else {
                    ForEach(model.videos) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                }
            } header: {
                Label(channel.title.isEmpty ? "Channel" : channel.title, systemImage: "person.crop.circle")
                    .lineLimit(1)
            }
        }
        .navigationTitle(channel.title.isEmpty ? "Channel" : channel.title)
        .brandBackdrop()
        .onAppear { model.loadIfNeeded() }
        .refreshable { await model.reload() }
    }
}
