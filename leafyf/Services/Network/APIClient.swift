import Foundation

// MARK: - Errors

/// Every failure a Leafy network call can produce, already phrased for the screen.
///
/// The views only ever switch on this, so no `URLError` codes leak into the UI layer.
enum APIError: Error, Equatable {
    /// The device has no usable connection. Worth a "you are offline" message rather
    /// than a generic failure.
    case offline
    case timedOut
    /// The request was cancelled — typically because the user kept typing. Callers
    /// swallow this instead of showing it.
    case cancelled
    case badStatus(Int)
    case decoding
    case invalidURL
    case unknown

    /// Message shown in the error state. Short, and never blames the user.
    var message: String {
        switch self {
        case .offline: "You appear to be offline."
        case .timedOut: "The request took too long."
        case .cancelled: "Cancelled."
        case .badStatus(404): "That article could not be found."
        case .badStatus: "Wikipedia could not answer right now."
        case .decoding: "That answer could not be read."
        case .invalidURL: "That address is not valid."
        case .unknown: "Something went wrong."
        }
    }

    var symbolName: String {
        switch self {
        case .offline: "wifi.slash"
        case .timedOut: "clock.badge.exclamationmark"
        case .badStatus(404): "questionmark.circle"
        default: "exclamationmark.triangle"
        }
    }

    /// Cancellation is a normal part of a debounced search, so views hide it.
    var isCancellation: Bool { self == .cancelled }

    /// Maps whatever `URLSession` threw onto the cases above.
    static func wrapping(_ error: Error) -> APIError {
        if error is CancellationError { return .cancelled }
        if let error = error as? APIError { return error }
        if error is DecodingError { return .decoding }

        guard let urlError = error as? URLError else { return .unknown }
        return switch urlError.code {
        case .cancelled: .cancelled
        case .timedOut: .timedOut
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed,
             .cannotFindHost, .cannotConnectToHost, .internationalRoamingOff:
            .offline
        default: .unknown
        }
    }
}

// MARK: - Client

/// A deliberately small JSON client for the two public, key-less APIs Leafy reads.
///
/// It exists mainly to put the shared `URLSession` configuration — cache, timeout and the
/// descriptive `User-Agent` Wikipedia asks every client to send — in one place.
struct APIClient: Sendable {
    static let shared = APIClient()

    /// Wikipedia's API policy asks for a client name that identifies the app.
    static let userAgent = "Leafy/1.0 (iOS houseplant app)"

    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .leafyShared, decoder: JSONDecoder = JSONDecoder()) {
        self.session = session
        self.decoder = decoder
    }

    /// Fetches and decodes JSON, translating every failure into an `APIError`.
    ///
    /// Cancellation-safe: awaiting `data(for:)` inside a cancelled `Task` throws, and the
    /// explicit check afterwards covers a cancellation that lands while decoding.
    func get<T: Decodable>(_ url: URL) async throws -> T {
        var request = URLRequest(url: url)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        // Reuse a cached body when there is one; the summaries Leafy shows are static
        // enough that a hit is worth more than freshness.
        request.cachePolicy = .useProtocolCachePolicy

        do {
            let (data, response) = try await session.data(for: request)
            try Task.checkCancellation()

            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw APIError.badStatus(http.statusCode)
            }

            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.wrapping(error)
        }
    }
}

// MARK: - Session

extension URLSession {
    /// One session for the whole app, with a memory + disk cache so revisiting an article
    /// is instant and works on a flaky connection.
    static let leafyShared: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        configuration.httpAdditionalHeaders = ["User-Agent": APIClient.userAgent]
        configuration.urlCache = URLCache(
            memoryCapacity: 8 * 1024 * 1024,
            diskCapacity: 64 * 1024 * 1024,
            diskPath: "leafy-network"
        )
        return URLSession(configuration: configuration)
    }()
}
