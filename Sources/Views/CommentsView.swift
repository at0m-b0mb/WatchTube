import SwiftUI
import Observation

struct CommentsView: View {
    let videoId: String
    @State private var model = CommentsModel()

    var body: some View {
        List {
            if model.isLoading {
                ForEach(0..<3, id: \.self) { _ in SkeletonRow() }
            } else if model.comments.isEmpty {
                EmptyStateRow(icon: "text.bubble", text: model.errorMessage ?? "No comments found.")
            } else {
                ForEach(model.comments) { comment in
                    CommentRow(comment: comment)
                }
            }
        }
        .navigationTitle("Comments")
        .brandBackdrop()
        .onAppear { model.load(videoId: videoId) }
    }
}

private struct CommentRow: View {
    let comment: Comment

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                ThumbnailView(url: comment.authorAvatarURL)
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())
                Text(comment.author)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                Spacer(minLength: 0)
                if let pub = comment.publishedText {
                    Text(pub)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            Text(comment.text)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(6)

            HStack(spacing: 8) {
                if let likes = comment.likeCount, !likes.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "hand.thumbsup")
                        Text(likes)
                    }
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                }
                if comment.isHearted {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

@MainActor @Observable
final class CommentsModel {
    var comments: [Comment] = []
    var isLoading = false
    var errorMessage: String?
    @ObservationIgnored private var loadedId: String?

    func load(videoId: String) {
        guard loadedId != videoId else { return }
        loadedId = videoId
        isLoading = true
        Task {
            do {
                comments = try await AppClient.make().comments(videoId: videoId)
            } catch {
                errorMessage = "Couldn't load comments."
            }
            isLoading = false
        }
    }
}
