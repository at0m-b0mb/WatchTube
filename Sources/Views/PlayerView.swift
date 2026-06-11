import SwiftUI
import AVKit

/// Plays the selected video, then lets you scroll to a "View Channel" shortcut
/// and an "Up Next" rail of related videos. Resolves a stream on appear, records
/// it to history, and offers a favorite toggle + retry. When YouTube demands
/// verification, a Google sign-in shortcut appears right in the error state.
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
            Text("Finding stream…")
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder private var channelLink: some View {
        if let channelId = model.video.channelId, !channelId.isEmpty {
            NavigationLink(value: ChannelRef(id: channelId, title: model.video.channelTitle)) {
                Label(model.video.channelTitle.isEmpty ? "View Channel" : model.video.channelTitle,
                      systemImage: "person.crop.circle")
                    .font(.caption)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.bordered)
            .tint(.gray)
        }
    }

    @ViewBuilder private var upNext: some View {
        if !model.related.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Up Next", systemImage: "text.line.first.and.arrowtriangle.forward")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 4)
                ForEach(model.related) { video in
                    NavigationLink(value: video) {
                        VideoRowView(video: video)
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(.white.opacity(0.06))
                            )
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

                    // Secondary when a sign-in button is already the primary CTA.
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
            AsyncImage(url: model.video.thumbnailURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Color.black
            }
            .overlay(Color.black.opacity(0.55))
            .blur(radius: 8)
            .ignoresSafeArea()
        }
    }
}
