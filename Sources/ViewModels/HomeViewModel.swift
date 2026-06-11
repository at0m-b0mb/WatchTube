import Foundation
import Observation

/// Loads the Home screen's trending shelf, with a graceful fallback to a default
/// search so the screen is never empty even when trending is gated.
@MainActor
@Observable
final class HomeViewModel {
    private(set) var trending: [Video] = []
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
        do {
            trending = try await client.trending()
        } catch {
            if let fallback = try? await client.search(query: "trending music"), !fallback.isEmpty {
                trending = fallback
            } else {
                errorMessage = "Couldn't load trending right now."
            }
        }
        isLoading = false
    }
}
