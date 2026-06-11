import SwiftUI
import Observation

struct ThumbnailView: View {
    let url: URL?
    @State private var model = ThumbnailModel()

    var body: some View {
        Group {
            if let img = model.image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else if model.failed {
                ZStack {
                    Color(white: 0.12)
                    Image(systemName: "play.slash")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            } else {
                ZStack {
                    Color(white: 0.12)
                    Image(systemName: "photo")
                        .font(.caption2)
                        .foregroundStyle(.quaternary)
                }
            }
        }
        .onAppear { model.load(url) }
    }
}

@MainActor @Observable
final class ThumbnailModel {
    var image: UIImage?
    var failed = false
    @ObservationIgnored private var loadingURL: String?

    func load(_ url: URL?) {
        guard let url else { failed = true; return }
        let key = url.absoluteString
        guard image == nil, !failed, loadingURL != key else { return }
        loadingURL = key
        if let cached = ThumbnailLoader.shared.cached(url) {
            image = cached
            return
        }
        ThumbnailLoader.shared.load(url) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self, self.loadingURL == key else { return }
                if let result {
                    self.image = result
                } else {
                    self.failed = true
                }
            }
        }
    }
}

final class ThumbnailLoader: @unchecked Sendable {
    static let shared = ThumbnailLoader()
    private let cache = NSCache<NSString, UIImage>()
    private var inflight: [String: [(UIImage?) -> Void]] = [:]
    private let lock = NSLock()
    private let session: URLSession

    private init() {
        cache.countLimit = 80
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache(memoryCapacity: 10_000_000, diskCapacity: 50_000_000)
        session = URLSession(configuration: config)
    }

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url.absoluteString as NSString)
    }

    func load(_ url: URL, completion: @escaping @Sendable (UIImage?) -> Void) {
        let key = url.absoluteString as NSString

        if let hit = cache.object(forKey: key) {
            DispatchQueue.main.async { completion(hit) }
            return
        }

        lock.lock()
        let keyStr = url.absoluteString
        if inflight[keyStr] != nil {
            inflight[keyStr]?.append(completion)
            lock.unlock()
            return
        }
        inflight[keyStr] = [completion]
        lock.unlock()

        var request = URLRequest(url: url)
        request.setValue("image/jpeg, image/png, image/*", forHTTPHeaderField: "Accept")
        session.dataTask(with: request) { [weak self] data, resp, _ in
            guard let self else { return }
            let img = data.flatMap { UIImage(data: $0) }
            if let img { self.cache.setObject(img, forKey: key) }

            self.lock.lock()
            let callbacks = self.inflight.removeValue(forKey: keyStr) ?? []
            self.lock.unlock()

            DispatchQueue.main.async {
                for cb in callbacks { cb(img) }
            }
        }.resume()
    }
}
