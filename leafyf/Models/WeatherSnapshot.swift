import Foundation
import SwiftUI

// MARK: - Snapshot

/// Everything the Today card needs about the weather at the saved place, flattened into
/// one `Codable` value so the last successful fetch can be cached in `UserDefaults` and
/// shown again offline.
///
/// Temperatures are kept in Celsius — the unit Open-Meteo answers in — and converted for
/// display through `Measurement`, so a US user sees °F without a second network request.
struct WeatherSnapshot: Codable, Equatable, Sendable {
    var placeID: String
    var placeName: String
    var fetchedAt: Date

    var temperatureC: Double
    var highC: Double
    var lowC: Double
    var humidity: Int
    var condition: WeatherCondition
    var isDaytime: Bool

    var sunrise: Date?
    var sunset: Date?
    var daylight: TimeInterval
    var precipitationMM: Double
    var uvIndexMax: Double

    /// Offset of the place, not of the phone: sunrise at a place you are not standing in
    /// must still read as a local morning time.
    var utcOffsetSeconds: Int
}

// MARK: - Formatting

extension WeatherSnapshot {
    private var timeZone: TimeZone {
        TimeZone(secondsFromGMT: utcOffsetSeconds) ?? .current
    }

    private func temperature(_ celsius: Double) -> String {
        Measurement(value: celsius, unit: UnitTemperature.celsius)
            .formatted(.measurement(width: .abbreviated, usage: .weather))
    }

    var temperatureText: String { temperature(temperatureC) }

    var lowTemperatureText: String { temperature(lowC) }

    var highLowText: String { "H \(temperature(highC))  ·  L \(temperature(lowC))" }

    var humidityText: String { humidity.formatted(.percent) }

    var daylightText: String {
        Duration.seconds(daylight)
            .formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    var uvText: String { uvIndexMax.formatted(.number.precision(.fractionLength(0))) }

    func clockText(for date: Date?) -> String {
        guard let date else { return "—" }
        return date.formatted(Date.FormatStyle(date: .omitted, time: .shortened, timeZone: timeZone))
    }

    var sunriseText: String { clockText(for: sunrise) }
    var sunsetText: String { clockText(for: sunset) }

    /// "2 hr. ago" — used to tell the user how stale a cached card is.
    var ageText: String {
        fetchedAt.formatted(.relative(presentation: .numeric, unitsStyle: .abbreviated))
    }

    var isStale: Bool {
        Date.now.timeIntervalSince(fetchedAt) > WeatherSnapshot.freshnessWindow
    }

    /// Open-Meteo updates roughly every 15 minutes; half an hour keeps the card honest
    /// without hammering a free endpoint every time Today appears.
    static let freshnessWindow: TimeInterval = 30 * 60
}

// MARK: - Preview

extension WeatherSnapshot {
    /// Lets `#Preview` and the settings section show a finished card without the network.
    /// `nonisolated` so it can be used as a default argument, which is evaluated outside
    /// the main actor even when the function it belongs to runs on it.
    nonisolated static let preview = WeatherSnapshot(
        placeID: SavedPlace.preview.id,
        placeName: SavedPlace.preview.name,
        fetchedAt: .now.addingTimeInterval(-600),
        temperatureC: 27,
        highC: 29,
        lowC: 18,
        humidity: 38,
        condition: .clear,
        isDaytime: true,
        sunrise: Calendar.current.date(bySettingHour: 7, minute: 12, second: 0, of: .now),
        sunset: Calendar.current.date(bySettingHour: 20, minute: 4, second: 0, of: .now),
        daylight: 12.87 * 3600,
        precipitationMM: 0,
        uvIndexMax: 8,
        utcOffsetSeconds: TimeZone.current.secondsFromGMT()
    )
}

// MARK: - Condition

/// The WMO weather codes Open-Meteo returns, folded into the handful of states worth
/// drawing differently. Anything unmapped falls back to `.unknown` rather than lying.
enum WeatherCondition: String, Codable, CaseIterable, Sendable {
    case clear
    case mainlyClear
    case partlyCloudy
    case overcast
    case fog
    case drizzle
    case freezingDrizzle
    case rain
    case freezingRain
    case snow
    case rainShowers
    case snowShowers
    case thunderstorm
    case unknown

    init(wmoCode: Int) {
        switch wmoCode {
        case 0: self = .clear
        case 1: self = .mainlyClear
        case 2: self = .partlyCloudy
        case 3: self = .overcast
        case 45, 48: self = .fog
        case 51, 53, 55: self = .drizzle
        case 56, 57: self = .freezingDrizzle
        case 61, 63, 65: self = .rain
        case 66, 67: self = .freezingRain
        case 71, 73, 75, 77: self = .snow
        case 80, 81, 82: self = .rainShowers
        case 85, 86: self = .snowShowers
        case 95, 96, 99: self = .thunderstorm
        default: self = .unknown
        }
    }

    var label: String {
        switch self {
        case .clear: "Clear"
        case .mainlyClear: "Mostly clear"
        case .partlyCloudy: "Partly cloudy"
        case .overcast: "Overcast"
        case .fog: "Fog"
        case .drizzle: "Drizzle"
        case .freezingDrizzle: "Freezing drizzle"
        case .rain: "Rain"
        case .freezingRain: "Freezing rain"
        case .snow: "Snow"
        case .rainShowers: "Showers"
        case .snowShowers: "Snow showers"
        case .thunderstorm: "Thunderstorms"
        case .unknown: "Weather"
        }
    }

    /// Day and night differ for the clear and lightly clouded states only — rain looks
    /// the same at midnight as it does at noon.
    func symbolName(isDaytime: Bool) -> String {
        switch self {
        case .clear: isDaytime ? "sun.max.fill" : "moon.stars.fill"
        case .mainlyClear: isDaytime ? "sun.min.fill" : "moon.fill"
        case .partlyCloudy: isDaytime ? "cloud.sun.fill" : "cloud.moon.fill"
        case .overcast: "cloud.fill"
        case .fog: "cloud.fog.fill"
        case .drizzle: "cloud.drizzle.fill"
        case .freezingDrizzle, .freezingRain: "cloud.sleet.fill"
        case .rain: "cloud.rain.fill"
        case .snow, .snowShowers: "cloud.snow.fill"
        case .rainShowers: isDaytime ? "cloud.sun.rain.fill" : "cloud.moon.rain.fill"
        case .thunderstorm: "cloud.bolt.rain.fill"
        case .unknown: "thermometer.medium"
        }
    }

    var isWet: Bool {
        switch self {
        case .drizzle, .freezingDrizzle, .rain, .freezingRain, .rainShowers, .thunderstorm: true
        default: false
        }
    }

    var isSunny: Bool {
        self == .clear || self == .mainlyClear
    }

    /// Two palette colours the card's hero gradient is built from.
    func gradientColors(isDaytime: Bool) -> [Color] {
        switch self {
        case .clear, .mainlyClear:
            isDaytime
                ? [Color(hex: 0xF2B441), Color(hex: 0xE07B4C)]
                : [Color(hex: 0x2C3E63), Color(hex: 0x14203A)]
        case .partlyCloudy:
            isDaytime
                ? [Color(hex: 0x6FA8D6), Color(hex: 0x4A78A8)]
                : [Color(hex: 0x38496E), Color(hex: 0x1C2740)]
        case .overcast, .fog:
            [Color(hex: 0x7C8B92), Color(hex: 0x4E5C63)]
        case .drizzle, .rain, .rainShowers:
            [Color(hex: 0x4A9BC4), Color(hex: 0x2B5F84)]
        case .freezingDrizzle, .freezingRain, .snow, .snowShowers:
            [Color(hex: 0x8FB8D6), Color(hex: 0x51708C)]
        case .thunderstorm:
            [Color(hex: 0x6B5F8C), Color(hex: 0x33294F)]
        case .unknown:
            [Color(hex: 0x5E8F68), Color(hex: 0x3A6244)]
        }
    }
}
