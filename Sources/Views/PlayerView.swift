import SwiftUI
import AVKit

/// Plays the selected video. Resolves a stream on appear, then hands the URL to
/// `AVPlayer` inside a SwiftUI `VideoPlayer` (audio + video).
///
/// If a future watchOS build ever rejects `VideoPlayer`, the legacy fallback is
/// WatchKit's `WKInterfaceMovie` / `presentMediaPlayerController`, which take the
/// same `resolution.url`.
struct PlayerView: View {
    @State private var model: PlayerViewModel

    init(video: Video) {
        _model = State(initialValue: PlayerViewModel(video: video))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .loading:
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Loading…")
                        .font(.footnote)
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
                    }
                    .padding()
                }
            }
        }
        .navigationTitle(model.title)
        .onAppear { model.loadIfNeeded() }
    }
}
