import SwiftUI

/// Landing screen: pick up where you left off, then a Trending shelf. A gear in
/// the top bar opens Settings.
struct HomeView: View {
    @Environment(LibraryStore.self) private var library
    @State private var model = HomeViewModel()

    var body: some View {
        List {
            if !library.history.isEmpty {
                Section("Continue Watching") {
                    ForEach(library.history.prefix(4)) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                }
            }

            Section("Trending") {
                if model.isLoading && model.trending.isEmpty {
                    LoadingRow()
                } else if let error = model.errorMessage, model.trending.isEmpty {
                    EmptyStateRow(icon: "wifi.exclamationmark", text: error)
                } else {
                    ForEach(model.trending) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                }
            }
        }
        .navigationTitle("WatchTube")
        .navigationDestination(for: Video.self) { PlayerView(video: $0) }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink { SettingsView() } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .onAppear { model.loadIfNeeded() }
        .refreshable { await model.reload() }
    }
}
