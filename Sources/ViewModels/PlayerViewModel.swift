import Foundation
import AVFoundation
import Observation

/// Resolves a video's playable stream and owns the `AVPlayer`.
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
    /// True when the failure is the kind a Google sign-in would likely fix —
    /// the player offers a sign-in shortcut next to Retry.
    private(set) var needsSignIn = false
    let video: Video

    @ObservationIgnored private var hasStarted = false

    init(video: Video) {
        self.video = video
        self.title = video.title
    }

    func loadIfNeeded() {
        guard !hasStarted else { return }
        hasStarted = true
        Task { await resolveAndPlay() }
    }

    func retry() {
        phase = .loading
        Task { await resolveAndPlay() }
    }

    private func resolveAndPlay() async {
        configureAudioSession()
        needsSignIn = false
        do {
            let resolution = try await AppClient.make().resolveStream(videoId: video.id)
            if !resolution.title.isEmpty { title = resolution.title }

            let item = AVPlayerItem(url: resolution.url)
            if UserDefaults.standard.bool(forKey: "dataSaver") {
                item.preferredPeakBitRate = 900_000   // ~0.9 Mbps cap for cellular/battery
            }
            let player = AVPlayer(playerItem: item)
            player.automaticallyWaitsToMinimizeStalling = true
            phase = .ready(player)
            player.play()
            Haptics.success()
        } catch {
            if case .loginRequired = error as? APIError {
                needsSignIn = !GoogleAuth.shared.isSignedIn
            }
            phase = .failed((error as? APIError)?.errorDescription ?? error.localizedDescription)
            Haptics.warn()
        }
    }

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }
}
