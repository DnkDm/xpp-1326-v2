import Foundation

// MARK: - Saved place

/// The location the weather card reports on.
///
/// Stored as JSON in `UserDefaults` rather than SwiftData: it is a single user preference,
/// not app content, and the weather services need it before any model context exists.
struct SavedPlace: Codable, Hashable, Identifiable, Sendable {
    var name: String
    var admin1: String?
    var country: String?
    var latitude: Double
    var longitude: Double

    /// Coordinates rounded to ~10 m, which is close enough to tell two saved places apart
    /// and stable enough to compare a cached snapshot against the current place.
    var id: String {
        String(format: "%.4f,%.4f", latitude, longitude)
    }

    /// "Lisbon, Portugal" — the region is dropped when it just repeats the city name.
    var subtitle: String {
        var parts: [String] = []
        if let admin1, !admin1.isEmpty, admin1 != name { parts.append(admin1) }
        if let country, !country.isEmpty { parts.append(country) }
        return parts.joined(separator: ", ")
    }

    var fullTitle: String {
        subtitle.isEmpty ? name : "\(name), \(subtitle)"
    }
}

extension SavedPlace {
    nonisolated static let preview = SavedPlace(
        name: "Lisbon",
        admin1: "Lisboa",
        country: "Portugal",
        latitude: 38.7167,
        longitude: -9.1333
    )
}

// MARK: - Geocoding result

/// One hit from the Open-Meteo geocoding search, shown in `PlacePickerView`.
struct PlaceResult: Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let admin1: String?
    let country: String?
    let countryCode: String?
    let latitude: Double
    let longitude: Double

    var place: SavedPlace {
        SavedPlace(name: name, admin1: admin1, country: country, latitude: latitude, longitude: longitude)
    }

    /// Flag emoji built from the ISO country code, so no image assets are needed.
    var flag: String {
        guard let code = countryCode, code.count == 2 else { return "📍" }
        return code.uppercased().unicodeScalars.reduce(into: "") { result, scalar in
            if let flagScalar = UnicodeScalar(127_397 + scalar.value) {
                result.unicodeScalars.append(flagScalar)
            }
        }
    }
}
