import Foundation
import Observation

/// Local, on-device library: Favorites, Watch History, and Recent Searches.
///
/// Everything is persisted in `UserDefaults` as JSON — small, fast, and private.
/// Nothing leaves the watch. Injected into the view tree via `.environment(...)`.
@MainActor
@Observable
final class LibraryStore {
    private(set) var favorites: [Video] = []
    private(set) var history: [Video] = []
    private(set) var recentSearches: [String] = []
    private(set) var queue: [Video] = []

    @ObservationIgnored private let defaults = UserDefaults.standard
    private let favKey = "library.favorites"
    private let histKey = "library.history"
    private let searchKey = "library.recentSearches"
    private let queueKey = "library.queue"
    private let maxHistory = 50
    private let maxSearches = 12

    init() {
        // Screenshot/demo seeding (simulator only): launch with WT_SEED=1.
        if ProcessInfo.processInfo.environment["WT_SEED"] == "1" {
            favorites = Array(SampleData.videos.prefix(4))
            history = SampleData.videos
            recentSearches = SampleData.searches
            queue = Array(SampleData.videos.prefix(2))
            return
        }
        favorites = loadVideos(favKey)
        history = loadVideos(histKey)
        recentSearches = defaults.stringArray(forKey: searchKey) ?? []
        queue = loadVideos(queueKey)
    }

    // MARK: Favorites

    func isFavorite(_ video: Video) -> Bool {
        favorites.contains { $0.id == video.id }
    }

    func toggleFavorite(_ video: Video) {
        if let index = favorites.firstIndex(where: { $0.id == video.id }) {
            favorites.remove(at: index)
        } else {
            favorites.insert(video, at: 0)
        }
        saveVideos(favorites, favKey)
    }

    func removeFavorite(_ video: Video) {
        favorites.removeAll { $0.id == video.id }
        saveVideos(favorites, favKey)
    }

    // MARK: History

    func recordWatch(_ video: Video) {
        history.removeAll { $0.id == video.id }
        history.insert(video, at: 0)
        if history.count > maxHistory { history = Array(history.prefix(maxHistory)) }
        saveVideos(history, histKey)
    }

    func clearHistory() {
        history = []
        saveVideos(history, histKey)
    }

    // MARK: Queue (Watch Later)

    func isQueued(_ video: Video) -> Bool {
        queue.contains { $0.id == video.id }
    }

    func toggleQueue(_ video: Video) {
        if let idx = queue.firstIndex(where: { $0.id == video.id }) {
            queue.remove(at: idx)
        } else {
            queue.append(video)
        }
        saveVideos(queue, queueKey)
    }

    func removeFromQueue(_ video: Video) {
        queue.removeAll { $0.id == video.id }
        saveVideos(queue, queueKey)
    }

    func clearQueue() {
        queue = []
        saveVideos(queue, queueKey)
    }

    // MARK: Recent searches

    func addRecentSearch(_ query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        recentSearches.removeAll { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > maxSearches { recentSearches = Array(recentSearches.prefix(maxSearches)) }
        defaults.set(recentSearches, forKey: searchKey)
    }

    func removeRecentSearch(_ query: String) {
        recentSearches.removeAll { $0 == query }
        defaults.set(recentSearches, forKey: searchKey)
    }

    func clearRecentSearches() {
        recentSearches = []
        defaults.set(recentSearches, forKey: searchKey)
    }

    // MARK: Persistence

    private func loadVideos(_ key: String) -> [Video] {
        guard let data = defaults.data(forKey: key),
              let videos = try? JSONDecoder().decode([Video].self, from: data) else { return [] }
        return videos
    }

    private func saveVideos(_ videos: [Video], _ key: String) {
        if let data = try? JSONEncoder().encode(videos) {
            defaults.set(data, forKey: key)
        }
    }
}
