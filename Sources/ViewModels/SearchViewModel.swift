import Foundation
import Observation

/// Drives the search screen: holds the query, runs the lookup, surfaces
/// as-you-type suggestions, and exposes loading / error state. `@Observable`
/// (watchOS 10+) means SwiftUI views re-render automatically when these change.
@MainActor
@Observable
final class SearchViewModel {
    var query = ""
    private(set) var results: [Video] = []
    private(set) var suggestions: [String] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    @ObservationIgnored private var searchTask: Task<Void, Never>?
    @ObservationIgnored private var suggestTask: Task<Void, Never>?

    func search() {
        searchTask?.cancel()
        clearSuggestions()

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

    /// Debounced autocomplete. Called on every keystroke; only a query that
    /// stays put for ~250ms actually hits the network.
    func updateSuggestions() {
        suggestTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            suggestions = []
            return
        }
        suggestTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(250))
            guard let self, !Task.isCancelled else { return }
            let found = await AppClient.make().suggestions(for: trimmed)
            if Task.isCancelled { return }
            self.suggestions = found
        }
    }

    func clearSuggestions() {
        suggestTask?.cancel()
        suggestions = []
    }
}
