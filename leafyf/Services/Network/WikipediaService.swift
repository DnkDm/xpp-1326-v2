import Foundation

/// Reads the public English Wikipedia APIs. No account, no key, no rate limit worth
/// worrying about at one request per keystroke-pause.
///
/// Two different APIs are used on purpose: the REST summary endpoint gives a clean
/// extract and lead image for a single page, while full-text search only exists on the
/// older Action API.
enum WikipediaService {
    private static let client = APIClient.shared

    // MARK: - Search

    /// Full-text search across article titles and bodies.
    ///
    /// Snippets come back as HTML with `<span class="searchmatch">` highlights around the
    /// matched words; they are stripped here so views never render markup as text.
    static func search(_ query: String, limit: Int = 20) async throws -> [WikipediaSearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let url = try actionURL([
            "action": "query",
            "list": "search",
            "srsearch": trimmed,
            "srlimit": String(limit),
            "srnamespace": "0",
            "format": "json",
            "origin": "*",
        ])

        let payload: SearchPayload = try await client.get(url)
        return payload.query.search.map {
            WikipediaSearchResult(title: $0.title, snippet: Self.plainText(from: $0.snippet))
        }
    }

    /// Lead thumbnails for a batch of titles, in one request rather than one per row.
    ///
    /// Returned as a dictionary keyed by the *requested* title, because Wikipedia
    /// normalises titles on the way in and the caller only knows what it asked for.
    static func thumbnails(for titles: [String], size: Int = 240) async throws -> [String: URL] {
        guard !titles.isEmpty else { return [:] }

        let url = try actionURL([
            "action": "query",
            "titles": titles.joined(separator: "|"),
            "prop": "pageimages",
            "piprop": "thumbnail",
            "pithumbsize": String(size),
            "pilicense": "any",
            "format": "json",
            "origin": "*",
        ])

        let payload: ThumbnailPayload = try await client.get(url)

        // `normalized` maps what was asked for onto what Wikipedia actually looked up.
        var requestedTitle: [String: String] = [:]
        for entry in payload.query.normalized ?? [] {
            requestedTitle[entry.to] = entry.from
        }

        var result: [String: URL] = [:]
        for page in (payload.query.pages ?? [:]).values {
            guard let source = page.thumbnail?.source, let url = URL(string: source) else { continue }
            result[requestedTitle[page.title] ?? page.title] = url
        }
        return result
    }

    // MARK: - Summary

    /// The REST summary for one article: description, extract, images and a mobile page URL.
    static func summary(for title: String) async throws -> SpeciesArticle {
        guard let encoded = encodedTitle(title) else { throw APIError.invalidURL }
        guard let url = URL(string: "https://en.wikipedia.org/api/rest_v1/page/summary/\(encoded)") else {
            throw APIError.invalidURL
        }

        let payload: SummaryPayload = try await client.get(url)
        return SpeciesArticle(
            title: payload.title,
            description: payload.description,
            extract: payload.extract ?? "",
            thumbnailURL: payload.thumbnail?.source.flatMap(URL.init(string:)),
            imageURL: payload.originalimage?.source.flatMap(URL.init(string:))
                ?? payload.thumbnail?.source.flatMap(URL.init(string:)),
            pageURL: payload.contentURLs?.mobile?.page.flatMap(URL.init(string:))
                ?? webPageURL(for: payload.title)
        )
    }

    /// Desktop-or-mobile page address, used as a fallback and for sharing.
    static func webPageURL(for title: String) -> URL? {
        guard let encoded = encodedTitle(title) else { return nil }
        return URL(string: "https://en.wikipedia.org/wiki/\(encoded)")
    }

    // MARK: - URL building

    private static func actionURL(_ parameters: [String: String]) throws -> URL {
        guard var components = URLComponents(string: "https://en.wikipedia.org/w/api.php") else {
            throw APIError.invalidURL
        }
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }

        // `URLComponents` leaves "+" alone, but the Action API reads it as a space.
        let encoded = components.percentEncodedQuery?.replacingOccurrences(of: "+", with: "%2B")
        components.percentEncodedQuery = encoded

        guard let url = components.url else { throw APIError.invalidURL }
        return url
    }

    /// Article titles travel in the path of the REST endpoint: spaces become underscores
    /// and everything else is percent-encoded, slashes included.
    private static func encodedTitle(_ title: String) -> String? {
        let allowed = CharacterSet.urlPathAllowed.subtracting(CharacterSet(charactersIn: "/?#"))
        return title
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "_")
            .addingPercentEncoding(withAllowedCharacters: allowed)
    }

    // MARK: - Snippet cleanup

    /// Strips the highlight markup and entities out of a search snippet.
    ///
    /// Hand-rolled rather than `NSAttributedString(html:)` because that has to be built on
    /// the main thread and is far too slow for twenty rows per keystroke.
    private static func plainText(from html: String) -> String {
        var text = ""
        var isInsideTag = false
        for character in html {
            switch character {
            case "<": isInsideTag = true
            case ">": isInsideTag = false
            default: if !isInsideTag { text.append(character) }
            }
        }

        let entities = [
            "&nbsp;": " ", "&amp;": "&", "&quot;": "\"", "&#39;": "'",
            "&lt;": "<", "&gt;": ">", "&mdash;": "—", "&ndash;": "–",
        ]
        for (entity, replacement) in entities {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }

        return text
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Payloads

/// `https://en.wikipedia.org/w/api.php?action=query&list=search`
private struct SearchPayload: Decodable {
    struct Query: Decodable {
        let search: [Item]
    }

    struct Item: Decodable {
        let title: String
        let snippet: String
    }

    let query: Query
}

/// `https://en.wikipedia.org/w/api.php?action=query&prop=pageimages`
private struct ThumbnailPayload: Decodable {
    struct Query: Decodable {
        let normalized: [Normalized]?
        /// Keyed by page id, which is of no use here — the title inside each page is.
        let pages: [String: Page]?
    }

    struct Normalized: Decodable {
        let from: String
        let to: String
    }

    struct Page: Decodable {
        let title: String
        let thumbnail: Image?
    }

    struct Image: Decodable {
        let source: String?
    }

    let query: Query
}

/// `https://en.wikipedia.org/api/rest_v1/page/summary/{title}`
private struct SummaryPayload: Decodable {
    struct Image: Decodable {
        let source: String?
    }

    struct ContentURLs: Decodable {
        struct Page: Decodable {
            let page: String?
        }

        let mobile: Page?
        let desktop: Page?
    }

    let title: String
    let description: String?
    let extract: String?
    let thumbnail: Image?
    let originalimage: Image?
    let contentURLs: ContentURLs?

    enum CodingKeys: String, CodingKey {
        case title, description, extract, thumbnail, originalimage
        case contentURLs = "content_urls"
    }
}
