import Foundation
import Observation

@MainActor
@Observable
final class ChannelViewModel {
    private(set) var videos: [Video] = []
    private(set) var header: InnerTubeClient.ChannelHeader?
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
        let client = await AppClient.make()
        async let headerFetch: InnerTubeClient.ChannelHeader? = try? client.channelHeader(channelId: channelId)
        async let videosFetch: [Video] = { do { return try await client.channelVideos(channelId: channelId) } catch { return [] } }()

        header = await headerFetch
        let vids = await videosFetch
        if vids.isEmpty && videos.isEmpty {
            errorMessage = "Couldn't load this channel."
        } else if !vids.isEmpty {
            videos = vids
        }
        isLoading = false
    }
}
