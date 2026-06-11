import SwiftUI

/// App shell: four swipeable tabs (Home / Search / Shorts / Library), each with
/// its own navigation stack. The shared LibraryStore is injected for the tree.
struct RootView: View {
    @State private var library = LibraryStore()
    @State private var selection: Tab = .initial

    enum Tab: Hashable {
        case home, search, shorts, library

        static var initial: Tab {
            switch ProcessInfo.processInfo.environment["WT_TAB"] {
            case "search": return .search
            case "shorts": return .shorts
            case "library": return .library
            default: return .home
            }
        }
    }

    var body: some View {
        Group {
            // Screenshot/demo hook (simulator only): WT_PLAY=<videoId> opens the
            // player directly. Ignored in normal use.
            if ProcessInfo.processInfo.environment["WT_SETTINGS"] == "1" {
                NavigationStack { SettingsView() }
            } else if let playId = ProcessInfo.processInfo.environment["WT_PLAY"], !playId.isEmpty {
                NavigationStack {
                    PlayerView(video: SampleData.videos.first { $0.id == playId }
                        ?? Video(id: playId, title: "Now Playing", channelTitle: "",
                                 thumbnailURL: URL(string: "https://i.ytimg.com/vi/\(playId)/hqdefault.jpg"),
                                 lengthText: nil))
                }
            } else {
                TabView(selection: $selection) {
                    NavigationStack { HomeView() }.tag(Tab.home)
                    NavigationStack { SearchView() }.tag(Tab.search)
                    NavigationStack { ShortsView() }.tag(Tab.shorts)
                    NavigationStack { LibraryView() }.tag(Tab.library)
                }
            }
        }
        .environment(library)
        .tint(.red)
    }
}
