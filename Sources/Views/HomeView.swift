import SwiftUI

struct HomeView: View {
    @Environment(LibraryStore.self) private var library
    @State private var model = HomeViewModel()

    var body: some View {
        List {
            if !library.history.isEmpty {
                Section {
                    ForEach(library.history.prefix(3)) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                } header: {
                    Label("Continue Watching", systemImage: "play.circle.fill")
                }
            }

            Section {
                if model.isLoading && model.trending.isEmpty {
                    ForEach(0..<3, id: \.self) { _ in
                        SkeletonCardRow()
                    }
                } else if let error = model.errorMessage, model.trending.isEmpty {
                    EmptyStateRow(icon: "wifi.exclamationmark", text: error)
                } else {
                    ForEach(model.trending) { video in
                        NavigationLink(value: video) { VideoCardView(video: video) }
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                }
            } header: {
                Label("Trending", systemImage: "flame.fill")
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("WatchTube")
        .navigationDestination(for: Video.self) { PlayerView(video: $0) }
        .navigationDestination(for: ChannelRef.self) { ChannelView(channel: $0) }
        .brandBackdrop()
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
