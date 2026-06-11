import Foundation
import Observation

/// Loads a feed of Shorts for the Shorts tab.
@MainActor
@Observable
final class ShortsViewModel {
    private(set) var shorts: [Video] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var loaded = false

    func loadIfNeeded() {
        guard !loaded else { return }
        loaded = true
        Task { await reload() }
    }

    func reload() async {
        isLoading = true
        errorMessage = nil
        let client = await AppClient.make()
        // A couple of broad, reliably-populated queries so the shelf is full.
        for query in ["shorts", "trending shorts", "funny shorts"] {
            if let found = try? await client.shorts(query: query), !found.isEmpty {
                shorts = found
                isLoading = false
                return
            }
        }
        errorMessage = "Couldn't load Shorts right now."
        isLoading = false
    }
}
