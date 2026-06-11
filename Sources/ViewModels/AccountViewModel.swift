import Foundation
import Observation

/// Loads the signed-in user's YouTube feeds (subscriptions / liked / watch
/// later). These ride the Google bearer token through InnerTube's `browse`,
/// which Google has restricted — so an empty result is an expected outcome,
/// not a crash. The view presents that honestly.
@MainActor
@Observable
final class AccountViewModel {
    enum Feed: String, CaseIterable, Identifiable {
        case subscriptions, liked, watchLater
        var id: String { rawValue }

        var title: String {
            switch self {
            case .subscriptions: "Subscriptions"
            case .liked: "Liked Videos"
            case .watchLater: "Watch Later"
            }
        }
        var icon: String {
            switch self {
            case .subscriptions: "rectangle.stack.badge.play"
            case .liked: "hand.thumbsup"
            case .watchLater: "clock.badge"
            }
        }
        var apiFeed: InnerTubeClient.AccountFeed {
            switch self {
            case .subscriptions: .subscriptions
            case .liked: .liked
            case .watchLater: .watchLater
            }
        }
    }

    private(set) var videos: [Video] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var loadedFeed: Feed?
    let feed: Feed

    init(feed: Feed) { self.feed = feed }

    func loadIfNeeded() {
        guard loadedFeed != feed else { return }
        loadedFeed = feed
        Task { await reload() }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        do {
            videos = try await AppClient.make().accountFeed(feed.apiFeed)
        } catch APIError.empty {
            videos = []
            errorMessage = "Nothing here yet — or YouTube didn't share this feed with the app. "
                + "Account feeds aren't always available to non-official clients."
        } catch {
            videos = []
            errorMessage = (error as? APIError)?.errorDescription
                ?? "Couldn't load \(feed.title)."
        }
        isLoading = false
    }
}
