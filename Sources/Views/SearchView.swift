import SwiftUI

/// Search tab: a field, live results, and tappable recent searches.
struct SearchView: View {
    @Environment(LibraryStore.self) private var library
    @State private var model = SearchViewModel()
    @State private var didAutoSearch = false

    var body: some View {
        List {
            Section {
                TextField("Search YouTube", text: $model.query)
                    .submitLabel(.search)
                    .onSubmit(runSearch)
                Button(action: runSearch) {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if model.isLoading {
                LoadingRow()
            }

            if let error = model.errorMessage, model.results.isEmpty, !model.isLoading {
                EmptyStateRow(icon: "exclamationmark.magnifyingglass", text: error)
            }

            if !model.results.isEmpty {
                Section("Results") {
                    ForEach(model.results) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                }
            } else if !library.recentSearches.isEmpty && !model.isLoading {
                Section("Recent") {
                    ForEach(library.recentSearches, id: \.self) { term in
                        Button {
                            model.query = term
                            runSearch()
                        } label: {
                            Label(term, systemImage: "clock.arrow.circlepath")
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                library.removeRecentSearch(term)
                            } label: {
                                Image(systemName: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Search")
        .navigationDestination(for: Video.self) { PlayerView(video: $0) }
        .onAppear(perform: autoSearchIfRequested)
    }

    private func runSearch() {
        let query = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        library.addRecentSearch(query)
        Haptics.tap()
        model.search()
    }

    private func autoSearchIfRequested() {
        guard !didAutoSearch,
              let query = ProcessInfo.processInfo.environment["WT_SEARCH"], !query.isEmpty else { return }
        didAutoSearch = true
        model.query = query
        model.search()
    }
}
