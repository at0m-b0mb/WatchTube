import SwiftUI
import AVKit

/// Plays the selected video over a blurred poster backdrop. Resolves a stream
/// on appear, records it to history, and offers a favorite toggle + retry.
/// When YouTube demands verification, a Google sign-in shortcut appears right
/// in the error state — and playback retries automatically after signing in.
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

            case .ready(let player):
                VideoPlayer(player: player)
                    .ignoresSafeArea()

            case .failed(let message):
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

                            Button {
                                model.retry()
                            } label: {
                                Label("Retry", systemImage: "arrow.clockwise")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        } else {
                            Button {
                                model.retry()
                            } label: {
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
            // Coming back from a successful sign-in: retry without making the
            // user hunt for the button.
            if case .failed = model.phase, model.needsSignIn, auth.isSignedIn {
                model.retry()
            }
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
