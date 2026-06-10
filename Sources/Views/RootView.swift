import SwiftUI

/// App shell. A single navigation stack rooted at Search; the player and
/// settings push on top of it.
struct RootView: View {
    var body: some View {
        NavigationStack {
            SearchView()
        }
    }
}
