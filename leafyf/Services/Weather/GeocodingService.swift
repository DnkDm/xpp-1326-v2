import Foundation

/// Open-Meteo's geocoding search — the same family of keyless endpoints as the forecast,
/// so the place picker needs no extra account or entitlement.
enum GeocodingService {
    static func search(_ query: String) async throws -> [PlaceResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        // The API rejects a single character; treat that as "keep typing", not an error.
        guard trimmed.count >= 2, let url = searchURL(for: trimmed) else { return [] }

        let response = try await WeatherFetch.json(SearchResponse.self, from: url)

        return (response.results ?? []).map { result in
            PlaceResult(
                id: result.id,
                name: result.name,
                admin1: result.admin1,
                country: result.country,
                countryCode: result.countryCode,
                latitude: result.latitude,
                longitude: result.longitude
            )
        }
    }

    private static func searchURL(for query: String) -> URL? {
        var components = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")
        components?.queryItems = [
            URLQueryItem(name: "name", value: query),
            URLQueryItem(name: "count", value: "8"),
            URLQueryItem(name: "language", value: Locale.current.language.languageCode?.identifier ?? "en"),
            URLQueryItem(name: "format", value: "json"),
        ]
        return components?.url
    }
}

// MARK: - Wire format

private struct SearchResponse: Decodable {
    let results: [Result]?

    struct Result: Decodable {
        let id: Int
        let name: String
        let latitude: Double
        let longitude: Double
        let country: String?
        let countryCode: String?
        let admin1: String?

        enum CodingKeys: String, CodingKey {
            case id, name, latitude, longitude, country, admin1
            case countryCode = "country_code"
        }
    }
}
