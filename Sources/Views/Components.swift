import SwiftUI

struct LoadingRow: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
                .tint(.red)
            Spacer()
        }
        .padding(.vertical, 8)
        .listRowBackground(Color.clear)
    }
}

struct EmptyStateRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.caption)
            Text(text)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

struct SkeletonCardRow: View {
    @State private var shimmer = false

    var body: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(white: 0.12))
            .frame(height: 110)
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 5) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 120, height: 10)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 80, height: 8)
                }
                .padding(10)
            }
            .opacity(shimmer ? 0.5 : 1.0)
            .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
            .onAppear { shimmer = true }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
    }
}

struct SkeletonRow: View {
    @State private var shimmer = false

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.12))
                .frame(width: 80, height: 48)
            VStack(alignment: .leading, spacing: 5) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 10)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.05))
                    .frame(width: 60, height: 8)
            }
        }
        .padding(.vertical, 3)
        .opacity(shimmer ? 0.5 : 1.0)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: shimmer)
        .onAppear { shimmer = true }
    }
}
