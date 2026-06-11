import SwiftUI

enum Theme {
    static let backdrop = LinearGradient(
        colors: [Color(red: 0.16, green: 0.03, blue: 0.05), .black],
        startPoint: .top, endPoint: .bottom
    )

    static let posterScrim = LinearGradient(
        colors: [.clear, .clear, .black.opacity(0.45), .black.opacity(0.92)],
        startPoint: .top, endPoint: .bottom
    )

    static let cardGlass = Color.white.opacity(0.06)
}

extension View {
    func brandBackdrop() -> some View {
        containerBackground(Theme.backdrop, for: .navigation)
    }
}
