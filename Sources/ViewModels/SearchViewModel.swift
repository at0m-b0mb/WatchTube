import Foundation
import Observation

/// Drives the search screen: holds the query, runs the lookup, and exposes
/// loading / error state. `@Observable` (watchOS 10+) means SwiftUI views
/// re-render automatically when these properties change.
@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    private(set) var results: [Video] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            errorMessage = nil
            return
        }

        isLoading = true
        errorMessage = nil

        searchTask = Task { [weak self] in
            guard let self else { return }
            do {
                let videos = try await AppClient.make().search(query: trimmed)
                if Task.isCancelled { return }
                self.results = videos
            } catch is CancellationError {
                return
            } catch {
                if Task.isCancelled { return }
                self.results = []
                self.errorMessage = (error as? APIError)?.errorDescription
                    ?? error.localizedDescription
            }
            self.isLoading = false
        }
    }
}
