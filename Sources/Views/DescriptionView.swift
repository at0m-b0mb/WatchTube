import SwiftUI
import Observation

struct DescriptionView: View {
    let video: Video
    @State private var model = DescriptionModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(video.title)
                    .font(.caption.weight(.semibold))

                if model.isLoading {
                    ProgressView().tint(.red).frame(maxWidth: .infinity)
                } else {
                    if let date = model.detail?.dateText {
                        Text(date)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    if let likes = model.detail?.likeCount {
                        HStack(spacing: 4) {
                            Image(systemName: "hand.thumbsup.fill")
                                .font(.system(size: 10))
                            Text(likes)
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(.secondary)
                    }

                    if let desc = model.detail?.description, !desc.isEmpty {
                        Divider()
                        Text(desc)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if model.detail != nil {
                        Text("No description available.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .navigationTitle("Description")
        .brandBackdrop()
        .onAppear { model.load(videoId: video.id) }
    }
}

@MainActor @Observable
final class DescriptionModel {
    var detail: InnerTubeClient.VideoDetail?
    var isLoading = false
    @ObservationIgnored private var loadedId: String?

    func load(videoId: String) {
        guard loadedId != videoId else { return }
        loadedId = videoId
        isLoading = true
        Task {
            detail = try? await AppClient.make().videoDetails(videoId: videoId)
            isLoading = false
        }
    }
}
