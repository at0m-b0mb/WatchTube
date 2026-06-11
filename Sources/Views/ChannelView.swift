import SwiftUI

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
                channelHeader
            }
            .listRowBackground(Color.clear)

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
                Label("Videos", systemImage: "play.rectangle.on.rectangle")
            }
        }
        .navigationTitle(channel.title.isEmpty ? "Channel" : channel.title)
        .navigationDestination(for: Video.self) { PlayerView(video: $0) }
        .navigationDestination(for: ChannelRef.self) { ChannelView(channel: $0) }
        .brandBackdrop()
        .onAppear { model.loadIfNeeded() }
        .refreshable { await model.reload() }
    }

    private var channelHeader: some View {
        VStack(spacing: 8) {
            let avatarURL = model.header?.avatarURL ?? channel.avatarURL
            if avatarURL != nil {
                ThumbnailView(url: avatarURL)
                    .frame(width: 52, height: 52)
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(.white.opacity(0.15), lineWidth: 1))
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(.secondary)
            }

            Text(channel.title)
                .font(.caption.weight(.semibold))
                .multilineTextAlignment(.center)

            HStack(spacing: 10) {
                if let subs = model.header?.subscriberCount ?? channel.subscriberCount {
                    Label(subs, systemImage: "person.2")
                }
                if let vids = model.header?.videoCount ?? channel.videoCount {
                    Label(vids, systemImage: "play.rectangle")
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(.secondary)

            if let desc = model.header?.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .lineLimit(3)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}
