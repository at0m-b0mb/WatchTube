import SwiftUI

/// Centered spinner sized for a list row.
struct LoadingRow: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }
}

/// Friendly empty-state row with an SF Symbol and a short line of guidance.
struct EmptyStateRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
