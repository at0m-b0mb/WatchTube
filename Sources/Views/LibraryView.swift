import SwiftUI

struct LibraryView: View {
    @Environment(LibraryStore.self) private var library
    private var auth: GoogleAuth { .shared }

    var body: some View {
        List {
            if auth.isSignedIn {
                Section {
                    ForEach(AccountViewModel.Feed.allCases) { feed in
                        NavigationLink {
                            AccountFeedView(feed: feed)
                        } label: {
                            Label(feed.title, systemImage: feed.icon)
                        }
                    }
                } header: {
                    Label("Your YouTube", systemImage: "play.circle")
                } footer: {
                    Text("Pulled live from your account. These feeds aren't always shared with non-official clients, so they may come up empty.")
                }
            }

            Section("Queue") {
                if library.queue.isEmpty {
                    EmptyStateRow(icon: "text.badge.plus", text: "Add videos to your queue to watch later.")
                } else {
                    ForEach(library.queue) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                            .swipeActions {
                                Button(role: .destructive) {
                                    library.removeFromQueue(video)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                            }
                    }
                    if library.queue.count > 1 {
                        Button(role: .destructive) {
                            library.clearQueue()
                            Haptics.tap()
                        } label: {
                            Label("Clear Queue", systemImage: "trash")
                        }
                    }
                }
            }

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
        .navigationDestination(for: ChannelRef.self) { ChannelView(channel: $0) }
        .brandBackdrop()
    }
}
