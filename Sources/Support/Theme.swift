import SwiftUI

/// Shared visual language so every screen feels like one app.
enum Theme {
    /// Deep red-to-black wash behind every navigation container — gives the
    /// whole app a subtle branded depth instead of flat black.
    static let backdrop = LinearGradient(
        colors: [Color(red: 0.16, green: 0.03, blue: 0.05), .black],
        startPoint: .top, endPoint: .bottom
    )

    /// Scrim laid over poster thumbnails so overlay text stays readable.
    static let posterScrim = LinearGradient(
        colors: [.clear, .black.opacity(0.85)],
        startPoint: .center, endPoint: .bottom
    )
}

extension View {
    /// Applies the brand backdrop behind this screen's navigation container.
    func brandBackdrop() -> some View {
        containerBackground(Theme.backdrop, for: .navigation)
    }
}
