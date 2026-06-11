import SwiftUI

/// Poster-style card: full-width 16:9 thumbnail under a gradient scrim, with
/// the title, channel, and duration laid over it. Used for the Home shelves
/// where a big visual beats a dense row.
struct VideoCardView: View {
    let video: Video

    var body: some View {
        ZStack(alignment: .bottomLeading) {
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
            .frame(height: 92)
            .frame(maxWidth: .infinity)
            .clipped()

            Theme.posterScrim

            VStack(alignment: .leading, spacing: 1) {
                Text(video.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if !video.channelTitle.isEmpty {
                    Text(video.channelTitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .frame(height: 92)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(alignment: .topTrailing) {
            if let length = video.lengthText {
                Text(length)
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1.5)
                    .background(.black.opacity(0.75))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(5)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.white.opacity(0.08))
        )
    }

    private func placeholder(systemImage: String) -> some View {
        ZStack {
            Theme.backdrop
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }
}
