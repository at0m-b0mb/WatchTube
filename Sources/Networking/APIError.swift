import Foundation

/// User-facing errors from the networking layer. Messages are written to be
/// short enough to read on a watch face.
enum APIError: LocalizedError {
    case badResponse(Int)
    case decoding(String)
    case notPlayable(String)   // YouTube returned a non-OK playabilityStatus
    case loginRequired(String) // same, but signing in with Google would likely fix it
    case noStream              // no HLS manifest and no clean progressive URL
    case empty                 // search returned nothing
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badResponse(let code):
            return "Server error (\(code)). Try again."
        case .decoding(let what):
            return "Couldn't read the response (\(what))."
        case .notPlayable(let reason), .loginRequired(let reason):
            return reason.isEmpty ? "This video can't be played." : reason
        case .noStream:
            return "No watch-playable stream found for this video."
        case .empty:
            return "No results."
        case .network(let msg):
            return msg
        }
    }
}
