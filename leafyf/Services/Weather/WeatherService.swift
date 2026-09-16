import Foundation

// MARK: - Errors

enum WeatherError: LocalizedError, Equatable {
    case offline
    case badResponse
    case noData

    var errorDescription: String? {
        switch self {
        case .offline: "No connection. Showing what Leafy already knows."
        case .badResponse: "The weather service is not answering right now."
        case .noData: "No forecast for this place."
        }
    }

    /// Short enough for the one-line footer under the card.
    var shortDescription: String {
        switch self {
        case .offline: "Offline"
        case .badResponse: "Service unavailable"
        case .noData: "No forecast"
        }
    }
}

// MARK: - Fetch helper

/// The whole networking layer this workstream needs: one shared session and one generic
/// decode. Deliberately independent of any other service so weather keeps working — and
/// keeps compiling — on its own.
enum WeatherFetch {
    static let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadRevalidatingCacheData
        return URLSession(configuration: configuration)
    }()

    static func json<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        do {
            let (data, response) = try await session.data(from: url)

            guard let http = response as? HTTPURLResponse else { throw WeatherError.badResponse }
            guard (200..<300).contains(http.statusCode) else { throw WeatherError.badResponse }

            return try JSONDecoder().decode(T.self, from: data)
        } catch let error as WeatherError {
            throw error
        } catch is DecodingError {
            throw WeatherError.badResponse
        } catch let error as URLError where error.code == .cancelled {
            // Cancellation is the caller changing its mind, not a failure to report.
            throw CancellationError()
        } catch is URLError {
            throw WeatherError.offline
        }
    }
}

// MARK: - Weather service

/// Open-Meteo forecast API. No key, no account, generous free tier.
enum WeatherService {
    static func snapshot(for place: SavedPlace) async throws -> WeatherSnapshot {
        guard let url = forecastURL(for: place) else { throw WeatherError.badResponse }

        let response = try await WeatherFetch.json(ForecastResponse.self, from: url)
        return try makeSnapshot(from: response, place: place)
    }

    private static func forecastURL(for place: SavedPlace) -> URL? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: String(place.latitude)),
            URLQueryItem(name: "longitude", value: String(place.longitude)),
            URLQueryItem(name: "current", value: "temperature_2m,relative_humidity_2m,weather_code,is_day"),
            URLQueryItem(
                name: "daily",
                value: "temperature_2m_max,temperature_2m_min,sunrise,sunset,daylight_duration,precipitation_sum,uv_index_max"
            ),
            URLQueryItem(name: "timezone", value: "auto"),
            // Unix timestamps sidestep parsing Open-Meteo's local-time ISO strings by hand.
            URLQueryItem(name: "timeformat", value: "unixtime"),
            URLQueryItem(name: "forecast_days", value: "3"),
        ]
        return components?.url
    }

    private static func makeSnapshot(from response: ForecastResponse, place: SavedPlace) throws -> WeatherSnapshot {
        let daily = response.daily
        guard !daily.time.isEmpty else { throw WeatherError.noData }

        func first<T>(_ values: [T?]?) -> T? {
            guard let values, let value = values.first else { return nil }
            return value
        }

        return WeatherSnapshot(
            placeID: place.id,
            placeName: place.name,
            fetchedAt: .now,
            temperatureC: response.current.temperature2m,
            highC: first(daily.temperature2mMax) ?? response.current.temperature2m,
            lowC: first(daily.temperature2mMin) ?? response.current.temperature2m,
            humidity: response.current.relativeHumidity2m,
            condition: WeatherCondition(wmoCode: response.current.weatherCode),
            isDaytime: response.current.isDay == 1,
            sunrise: first(daily.sunrise).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            sunset: first(daily.sunset).map { Date(timeIntervalSince1970: TimeInterval($0)) },
            daylight: first(daily.daylightDuration) ?? 0,
            precipitationMM: first(daily.precipitationSum) ?? 0,
            uvIndexMax: first(daily.uvIndexMax) ?? 0,
            utcOffsetSeconds: response.utcOffsetSeconds
        )
    }
}

// MARK: - Wire format

/// Mirrors the Open-Meteo payload one to one. Keys are spelled out rather than derived with
/// `convertFromSnakeCase`, which turns `temperature_2m` into a name that never matches.
/// Every daily array is optional-per-element because the API sends `null` where a value
/// does not exist (no sunset above the polar circle, no UV index at night).
private struct ForecastResponse: Decodable {
    let utcOffsetSeconds: Int
    let current: Current
    let daily: Daily

    enum CodingKeys: String, CodingKey {
        case utcOffsetSeconds = "utc_offset_seconds"
        case current, daily
    }

    struct Current: Decodable {
        let temperature2m: Double
        let relativeHumidity2m: Int
        let weatherCode: Int
        let isDay: Int

        enum CodingKeys: String, CodingKey {
            case temperature2m = "temperature_2m"
            case relativeHumidity2m = "relative_humidity_2m"
            case weatherCode = "weather_code"
            case isDay = "is_day"
        }
    }

    struct Daily: Decodable {
        let time: [Int]
        let temperature2mMax: [Double?]?
        let temperature2mMin: [Double?]?
        let sunrise: [Int?]?
        let sunset: [Int?]?
        let daylightDuration: [Double?]?
        let precipitationSum: [Double?]?
        let uvIndexMax: [Double?]?

        enum CodingKeys: String, CodingKey {
            case time
            case temperature2mMax = "temperature_2m_max"
            case temperature2mMin = "temperature_2m_min"
            case sunrise, sunset
            case daylightDuration = "daylight_duration"
            case precipitationSum = "precipitation_sum"
            case uvIndexMax = "uv_index_max"
        }
    }
}
