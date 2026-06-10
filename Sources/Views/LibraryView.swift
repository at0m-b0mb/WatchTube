import SwiftUI

/// Library tab: your Favorites and Watch History, all stored locally.
struct LibraryView: View {
    @Environment(LibraryStore.self) private var library

    var body: some View {
        List {
            Section("Favorites") {
                if library.favorites.isEmpty {
                    EmptyStateRow(icon: "heart", text: "Tap the heart on any video to save it here.")
                } else {
                    ForEach(library.favorites) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    library.removeFavorite(video)
                                } label: {
                                    Image(systemName: "heart.slash")
                                }
                            }
                    }
                }
            }

            Section("History") {
                if library.history.isEmpty {
                    EmptyStateRow(icon: "clock", text: "Videos you watch show up here.")
                } else {
                    ForEach(library.history) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                    Button(role: .destructive) {
                        library.clearHistory()
                        Haptics.tap()
                    } label: {
                        Label("Clear History", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Library")
        .navigationDestination(for: Video.self) { PlayerView(video: $0) }
    }
}
