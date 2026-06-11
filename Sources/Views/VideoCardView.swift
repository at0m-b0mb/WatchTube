import SwiftUI

struct VideoCardView: View {
    let video: Video

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            ThumbnailView(url: video.thumbnailURL)
                .frame(height: 110)
                .frame(maxWidth: .infinity)
                .clipped()

            LinearGradient(
                colors: [.clear, .clear, .black.opacity(0.45), .black.opacity(0.92)],
                startPoint: .top, endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 7) {
                if video.channelAvatarURL != nil {
                    ThumbnailView(url: video.channelAvatarURL)
                        .frame(width: 22, height: 22)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.2), lineWidth: 0.5))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .shadow(color: .black.opacity(0.6), radius: 2, y: 1)
                    HStack(spacing: 4) {
                        if !video.channelTitle.isEmpty {
                            Text(video.channelTitle).lineLimit(1)
                        }
                        if let views = video.viewCount, !video.channelTitle.isEmpty {
                            Text("\u{00B7}")
                            Text(views).lineLimit(1)
                        } else if let views = video.viewCount {
                            Text(views).lineLimit(1)
                        }
                        if let pub = video.publishedText {
                            Text("\u{00B7}")
                            Text(pub).lineLimit(1)
                        }
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 7)
        }
        .frame(height: 110)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(alignment: .topTrailing) {
            if let length = video.lengthText {
                Text(length)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(6)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .strokeBorder(.white.opacity(0.1))
        )
    }
}
