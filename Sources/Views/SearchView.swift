import SwiftUI

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
                    .onChange(of: model.query) { _, _ in model.updateSuggestions() }
                Button(action: runSearch) {
                    Label("Search", systemImage: "magnifyingglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 2, leading: 0, bottom: 2, trailing: 0))
                .disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if !model.suggestions.isEmpty && model.results.isEmpty && !model.isLoading {
                Section {
                    ForEach(model.suggestions, id: \.self) { term in
                        Button {
                            model.query = term
                            runSearch()
                        } label: {
                            Label {
                                Text(term).lineLimit(1)
                            } icon: {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.caption2)
                            }
                        }
                    }
                } header: {
                    Label("Suggestions", systemImage: "sparkles")
                        .foregroundStyle(.secondary)
                }
            }

            if model.isLoading {
                Section {
                    ForEach(0..<4, id: \.self) { _ in
                        SkeletonRow()
                    }
                }
            }

            if let error = model.errorMessage, model.results.isEmpty, !model.isLoading {
                EmptyStateRow(icon: "exclamationmark.magnifyingglass", text: error)
            }

            if !model.results.isEmpty {
                Section {
                    ForEach(model.results) { video in
                        NavigationLink(value: video) { VideoRowView(video: video) }
                    }
                } header: {
                    Label("Results", systemImage: "play.rectangle.on.rectangle")
                }
            } else if model.suggestions.isEmpty && !library.recentSearches.isEmpty && !model.isLoading {
                Section {
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
                } header: {
                    Label("Recent", systemImage: "clock")
                }
            }
        }
        .navigationTitle("Search")
        .navigationDestination(for: Video.self) { PlayerView(video: $0) }
        .navigationDestination(for: ChannelRef.self) { ChannelView(channel: $0) }
        .brandBackdrop()
        .onAppear(perform: autoSearchIfRequested)
    }

    private func runSearch() {
        let query = model.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        model.clearSuggestions()
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
