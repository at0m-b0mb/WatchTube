import SwiftUI
import AVKit

struct PlayerView: View {
    @Environment(LibraryStore.self) private var library
    @State private var model: PlayerViewModel

    private var auth: GoogleAuth { .shared }

    init(video: Video) {
        _model = State(initialValue: PlayerViewModel(video: video))
    }

    var body: some View {
        ZStack {
            backdrop

            switch model.phase {
            case .loading:
                loadingView

            case .ready(let player):
                ScrollView {
                    VStack(spacing: 10) {
                        VideoPlayer(player: player)
                            .frame(height: 138)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14)
                                    .strokeBorder(.white.opacity(0.08))
                            )

                        videoInfo
                        actionButtons
                        channelLink
                        upNext
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 8)
                }

            case .failed(let message):
                failureView(message)
            }
        }
        .navigationTitle(model.title)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    library.toggleFavorite(model.video)
                    Haptics.tap()
                } label: {
                    Image(systemName: library.isFavorite(model.video) ? "heart.fill" : "heart")
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            library.recordWatch(model.video)
            model.loadIfNeeded()
            if case .failed = model.phase, model.needsSignIn, auth.isSignedIn {
                model.retry()
            }
        }
    }

    // MARK: - Video info bar

    private var videoInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                if model.video.channelAvatarURL != nil {
                    ThumbnailView(url: model.video.channelAvatarURL)
                        .frame(width: 24, height: 24)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(model.video.channelTitle.isEmpty ? "Unknown" : model.video.channelTitle)
                        .font(.caption2.weight(.medium))
                        .lineLimit(1)
                    if let views = model.video.viewCount {
                        Text(views)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Action buttons

    private var actionButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                NavigationLink {
                    DescriptionView(video: model.video)
                } label: {
                    Label("Description", systemImage: "doc.text")
                }

                NavigationLink {
                    CommentsView(videoId: model.video.id)
                } label: {
                    Label("Comments", systemImage: "text.bubble")
                }

                Button {
                    library.toggleQueue(model.video)
                    Haptics.tap()
                } label: {
                    Label(library.isQueued(model.video) ? "Queued" : "Queue",
                          systemImage: library.isQueued(model.video) ? "text.badge.checkmark" : "text.badge.plus")
                }

                if case .ready = model.phase {
                    NavigationLink {
                        SpeedPickerView(model: model)
                    } label: {
                        Label(model.currentSpeed == 1.0 ? "Speed" : "\(model.currentSpeed, specifier: "%.2g")x",
                              systemImage: "gauge.with.dots.needle.33percent")
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(.gray)
            .font(.caption2)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Pieces

    private var loadingView: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
                .tint(.red)
            Text(model.title)
                .font(.caption2)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("Finding stream\u{2026}")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder private var channelLink: some View {
        if let channelId = model.video.channelId, !channelId.isEmpty {
            NavigationLink(value: ChannelRef(id: channelId,
                                             title: model.video.channelTitle,
                                             avatarURL: model.video.channelAvatarURL)) {
                HStack(spacing: 8) {
                    if model.video.channelAvatarURL != nil {
                        ThumbnailView(url: model.video.channelAvatarURL)
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    Text(model.video.channelTitle.isEmpty ? "View Channel" : model.video.channelTitle)
                        .font(.caption)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }

    @ViewBuilder private var upNext: some View {
        if !model.related.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                ForEach(model.related.prefix(8)) { video in
                    NavigationLink(value: video) {
                        VideoRowView(video: video)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func failureView(_ message: String) -> some View {
        ScrollView {
            VStack(spacing: 10) {
                Image(systemName: model.needsSignIn
                      ? "person.crop.circle.badge.exclamationmark"
                      : "exclamationmark.triangle")
                    .font(.title3)
                    .foregroundStyle(.yellow)
                Text(message)
                    .font(.footnote)
                    .multilineTextAlignment(.center)

                if model.needsSignIn {
                    NavigationLink {
                        GoogleSignInView()
                    } label: {
                        Label("Sign in with Google", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Button { model.retry() } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button { model.retry() } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .padding()
        }
    }

    @ViewBuilder private var backdrop: some View {
        if case .ready = model.phase {
            Color.black.ignoresSafeArea()
        } else {
            ThumbnailView(url: model.video.thumbnailURL)
                .overlay(Color.black.opacity(0.55))
                .blur(radius: 8)
                .ignoresSafeArea()
        }
    }
}
