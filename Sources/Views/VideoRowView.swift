import SwiftUI

/// One row in the search results list: thumbnail + title + channel/duration.
struct VideoRowView: View {
    let video: Video

    var body: some View {
        HStack(spacing: 8) {
            AsyncImage(url: video.thumbnailURL) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().aspectRatio(contentMode: .fill)
                case .failure:
                    placeholder(systemImage: "play.slash")
                default:
                    placeholder(systemImage: "photo")
                }
            }
            .frame(width: 56, height: 36)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption)
                    .lineLimit(2)
                HStack(spacing: 4) {
                    Text(video.channelTitle)
                        .lineLimit(1)
                    if let length = video.lengthText {
                        Spacer(minLength: 2)
                        Text(length)
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    private func placeholder(systemImage: String) -> some View {
        ZStack {
            Color.gray.opacity(0.25)
            Image(systemName: systemImage)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
