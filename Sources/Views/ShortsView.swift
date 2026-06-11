import SwiftUI
import AVKit
import AVFoundation

/// Shorts tab: swipe vertically through Shorts. Only the centered one resolves
/// a stream and plays (and loops) — so we never hold more than one AVPlayer,
/// which keeps memory and battery sane on the watch.
struct ShortsView: View {
    @State private var model = ShortsViewModel()
    @State private var selection = 0

    var body: some View {
        Group {
            if model.shorts.isEmpty {
                List {
                    if model.isLoading {
                        LoadingRow()
                    } else {
                        EmptyStateRow(icon: "play.rectangle.on.rectangle",
                                      text: model.errorMessage ?? "Loading Shorts…")
                    }
                }
                .brandBackdrop()
            } else {
                TabView(selection: $selection) {
                    ForEach(Array(model.shorts.enumerated()), id: \.element.id) { index, short in
                        ShortPage(video: short, isActive: selection == index)
                            .tag(index)
                    }
                }
                .tabViewStyle(.verticalPage)
                .ignoresSafeArea()
            }
        }
        .navigationTitle("Shorts")
        .onAppear { model.loadIfNeeded() }
    }
}

/// A single full-screen Short. Resolves + plays (looping) when it becomes the
/// active page, and tears the player down when it scrolls away.
private struct ShortPage: View {
    let video: Video
    let isActive: Bool

    @Environment(LibraryStore.self) private var library
    @State private var player: AVPlayer?
    @State private var looper: ShortLooper?
    @State private var failed = false

    var body: some View {
        ZStack {
            ThumbnailView(url: video.thumbnailURL)
                .overlay(Color.black.opacity(player == nil ? 0.4 : 0))
                .ignoresSafeArea()

            if let player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)   // let our overlay buttons win
            } else if !failed {
                ProgressView().controlSize(.large).tint(.white)
            }

            // Title + favorite, gradient-scrimmed for legibility.
            VStack {
                Spacer()
                HStack(alignment: .bottom) {
                    Text(video.title)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(3)
                        .shadow(radius: 3)
                    Spacer(minLength: 6)
                    Button {
                        library.toggleFavorite(video)
                        Haptics.tap()
                    } label: {
                        Image(systemName: library.isFavorite(video) ? "heart.fill" : "heart")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 6)
            }
        }
        .onChange(of: isActive) { _, active in
            active ? start() : stop()
        }
        .onAppear { if isActive { start() } }
        .onDisappear { stop() }
    }

    private func start() {
        guard player == nil else { player?.play(); return }
        failed = false
        Task {
            do {
                let resolution = try await AppClient.make().resolveStream(videoId: video.id)
                let item = AVPlayerItem(url: resolution.url)
                if UserDefaults.standard.bool(forKey: "dataSaver") {
                    item.preferredPeakBitRate = 900_000
                }
                configureAudio()
                let avPlayer = AVPlayer(playerItem: item)
                guard isActive else { return }      // user already swiped on
                looper = ShortLooper(player: avPlayer)
                player = avPlayer
                avPlayer.play()
                library.recordWatch(video)
            } catch {
                failed = true
                Haptics.warn()
            }
        }
    }

    private func stop() {
        player?.pause()
        looper = nil
        player = nil
    }

    private func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}

/// Seeks a player back to the start whenever it reaches the end — giving Shorts
/// their signature loop without pulling in AVQueuePlayer machinery.
private final class ShortLooper {
    private var token: NSObjectProtocol?

    init(player: AVPlayer) {
        token = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak player] _ in
            player?.seek(to: .zero)
            player?.play()
        }
    }

    deinit {
        if let token { NotificationCenter.default.removeObserver(token) }
    }
}
