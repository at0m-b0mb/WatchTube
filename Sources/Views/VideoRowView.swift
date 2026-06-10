import SwiftUI

/// One row in a video list: thumbnail with a duration badge, title, channel,
/// and a heart if it's a favorite.
struct VideoRowView: View {
    let video: Video
    @Environment(LibraryStore.self) private var library

    var body: some View {
        HStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
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
                .frame(width: 62, height: 40)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                if let length = video.lengthText {
                    Text(length)
                        .font(.system(size: 9, weight: .semibold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(.black.opacity(0.75))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 3))
                        .padding(2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(video.title)
                    .font(.caption)
                    .lineLimit(2)
                Text(video.channelTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if library.isFavorite(video) {
                Spacer(minLength: 0)
                Image(systemName: "heart.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.red)
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
