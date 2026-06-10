import SwiftUI
import AVKit

/// Plays the selected video over a blurred poster backdrop. Resolves a stream on
/// appear, records it to history, and offers a favorite toggle + retry.
struct PlayerView: View {
    @Environment(LibraryStore.self) private var library
    @State private var model: PlayerViewModel

    init(video: Video) {
        _model = State(initialValue: PlayerViewModel(video: video))
    }

    var body: some View {
        ZStack {
            backdrop

            switch model.phase {
            case .loading:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading…")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

            case .ready(let player):
                VideoPlayer(player: player)
                    .ignoresSafeArea()

            case .failed(let message):
                ScrollView {
                    VStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.title3)
                            .foregroundStyle(.yellow)
                        Text(message)
                            .font(.footnote)
                            .multilineTextAlignment(.center)
                        Button {
                            model.retry()
                        } label: {
                            Label("Retry", systemImage: "arrow.clockwise")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
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
