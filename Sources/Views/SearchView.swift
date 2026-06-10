import SwiftUI

/// Root screen: a search field, results, and a link into Settings.
struct SearchView: View {
    @State private var model = SearchViewModel()

    var body: some View {
        List {
            Section {
                TextField("Search YouTube", text: $model.query)
                    .submitLabel(.search)
                    .onSubmit { model.search() }
                Button {
                    model.search()
                } label: {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .disabled(model.query.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if model.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            }

            if let error = model.errorMessage, model.results.isEmpty, !model.isLoading {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if !model.results.isEmpty {
                Section("Results") {
                    ForEach(model.results) { video in
                        NavigationLink(value: video) {
                            VideoRowView(video: video)
                        }
                    }
                }
            }

            Section {
                NavigationLink {
                    SettingsView()
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
            }
        }
        .navigationTitle("WatchTube")
        .navigationDestination(for: Video.self) { video in
            PlayerView(video: video)
        }
    }
}
