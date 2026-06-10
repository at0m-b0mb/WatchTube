import Foundation
import AVFoundation
import Observation

/// Resolves a video's playable stream and owns the `AVPlayer`.
///
/// The view watches `phase`: it shows a spinner while resolving, the player
/// once a stream URL is ready, or a readable message if something failed.
@MainActor
@Observable
final class PlayerViewModel {
    enum Phase {
        case loading
        case ready(AVPlayer)
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var title: String

    @ObservationIgnored private let video: Video
    @ObservationIgnored private var hasStarted = false

    init(video: Video) {
        self.video = video
        self.title = video.title
    }

    /// Safe to call from `.onAppear` — only resolves once.
    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { [weak self] in
            await self?.resolveAndPlay()
        }
    }

    private func resolveAndPlay() async {
        configureAudioSession()
        do {
            let resolution = try await AppClient.make().resolveStream(videoId: video.id)
            if !resolution.title.isEmpty { title = resolution.title }

            let player = AVPlayer(url: resolution.url)
            player.automaticallyWaitsToMinimizeStalling = true   // smoother on cellular
            phase = .ready(player)
            player.play()
        } catch {
            phase = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Routes audio for long-form video so it plays through the watch speaker or
    /// paired AirPods. Without an active playback session, watchOS stays silent.
    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}
