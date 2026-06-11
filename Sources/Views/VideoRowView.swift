import SwiftUI

struct VideoRowView: View {
    let video: Video
    @Environment(LibraryStore.self) private var library

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                ThumbnailView(url: video.thumbnailURL)
                    .frame(width: 80, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(.white.opacity(0.1))
                    )

                if let length = video.lengthText {
                    Text(length)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.8))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 5) {
                    if video.channelAvatarURL != nil {
                        ThumbnailView(url: video.channelAvatarURL)
                            .frame(width: 14, height: 14)
                            .clipShape(Circle())
                    }
                    if !video.channelTitle.isEmpty {
                        Text(video.channelTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                HStack(spacing: 4) {
                    if let views = video.viewCount {
                        Text(views).lineLimit(1)
                    }
                    if let pub = video.publishedText {
                        if video.viewCount != nil { Text("\u{00B7}") }
                        Text(pub).lineLimit(1)
                    }
                }
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            }

            if library.isFavorite(video) {
                Spacer(minLength: 0)
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
            }
        }
        .padding(.vertical, 3)
    }
}
