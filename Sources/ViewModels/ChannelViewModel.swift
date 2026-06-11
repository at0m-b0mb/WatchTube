import Foundation
import Observation

/// Loads a single channel's uploads.
@MainActor
@Observable
final class ChannelViewModel {
    private(set) var videos: [Video] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var loaded = false
    private let channelId: String

    init(channelId: String) { self.channelId = channelId }

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        Task { await reload() }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            videos = try await AppClient.make().channelVideos(channelId: channelId)
        } catch {
            videos = []
            errorMessage = (error as? APIError)?.errorDescription
                ?? "Couldn't load this channel."
        }
        isLoading = false
    }
}
