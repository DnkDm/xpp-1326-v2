import SwiftUI

// MARK: - Tip

/// One line of weather-driven advice, already tied to a symbol and a tint so the card
/// only has to lay it out.
struct CareTip: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let symbolName: String
    let tint: Color
}

// MARK: - Advisor

/// Turns a forecast plus the user's actual shelf of plants into at most three short,
/// specific suggestions.
///
/// Pure and synchronous on purpose: the rules are the interesting part, and they stay
/// easy to read, reorder and test when nothing else is going on in here. Every rule is
/// something a plant owner could have worked out themselves — the card just notices it
/// first, and names the plants it applies to.
enum CareAdvisor {
    static func advice(for snapshot: WeatherSnapshot, plants: [Plant]) -> [CareTip] {
        let shelf = Shelf(plants: plants)

        let candidates = [
            frostTip(snapshot, shelf),
            heatTip(snapshot, shelf),
            dryAirTip(snapshot, shelf),
            sunburnTip(snapshot, shelf),
            rainTip(snapshot, shelf),
            muggyTip(snapshot, shelf),
            shortDayTip(snapshot, shelf),
        ]

        let tips = candidates.compactMap { $0 }
        return Array(tips.prefix(3))
    }

    // MARK: - Rules

    /// Cold glass kills more houseplants in winter than the cold itself.
    private static func frostTip(_ snapshot: WeatherSnapshot, _ shelf: Shelf) -> CareTip? {
        guard snapshot.lowC <= 4 else { return nil }

        return CareTip(
            id: "frost",
            title: "Move plants off cold windowsills",
            detail: shelf.list(shelf.tender, fallback: "Tropical plants")
                + " will sulk at \(snapshot.lowTemperatureText). Keep leaves off the glass and skip tonight's watering.",
            symbolName: "thermometer.snowflake",
            tint: .leafWater
        )
    }

    /// Warm, dry air empties a pot days earlier than the calendar says.
    private static func heatTip(_ snapshot: WeatherSnapshot, _ shelf: Shelf) -> CareTip? {
        guard snapshot.temperatureC >= 26, snapshot.humidity <= 50 else { return nil }

        return CareTip(
            id: "heat",
            title: "Check the soil a day early",
            detail: shelf.list(shelf.thirsty, fallback: "Leafy plants")
                + " dry out fast at \(snapshot.temperatureText). Water when the top 2 cm feel dry.",
            symbolName: "drop.fill",
            tint: .leafWater
        )
    }

    /// Humidity is the one thing indoor growers most often forget to look at.
    private static func dryAirTip(_ snapshot: WeatherSnapshot, _ shelf: Shelf) -> CareTip? {
        guard snapshot.humidity <= 38 else { return nil }

        if shelf.humidityLovers.isEmpty {
            return CareTip(
                id: "dry-air",
                title: "Air is dry today",
                detail: "At \(snapshot.humidityText) humidity, grouping pots together keeps a little moisture around the leaves.",
                symbolName: "humidity",
                tint: .leafMint
            )
        }

        return CareTip(
            id: "dry-air",
            title: "Raise the humidity",
            detail: shelf.list(shelf.humidityLovers)
                + " will brown at the tips at \(snapshot.humidityText). Mist them or stand the pot on damp pebbles.",
            symbolName: "humidity.fill",
            tint: .leafMint
        )
    }

    /// Glass magnifies a high UV index, and succulents scorch before they wilt.
    private static func sunburnTip(_ snapshot: WeatherSnapshot, _ shelf: Shelf) -> CareTip? {
        guard snapshot.uvIndexMax >= 7, snapshot.condition.isSunny else { return nil }

        return CareTip(
            id: "uv",
            title: "Shade the midday window",
            detail: shelf.list(shelf.succulents, fallback: "Thick-leaved plants")
                + " can scorch behind glass at UV \(snapshot.uvText). Pull them back a hand's width or draw a sheer curtain.",
            symbolName: "sun.max.trianglebadge.exclamationmark.fill",
            tint: .leafGold
        )
    }

    /// Rain outside is free soft water — and a reason not to water the balcony.
    private static func rainTip(_ snapshot: WeatherSnapshot, _ shelf: Shelf) -> CareTip? {
        guard snapshot.condition.isWet || snapshot.precipitationMM >= 2 else { return nil }

        let outdoorNote = shelf.hasOutdoorPlants
            ? "Your balcony plants are being watered for you. "
            : ""

        return CareTip(
            id: "rain",
            title: "Let the rain do the work",
            detail: outdoorNote
                + "Collected rainwater is softer than tap water — "
                + shelf.list(shelf.humidityLovers, fallback: "fussy plants")
                + " prefer it.",
            symbolName: "cloud.rain.fill",
            tint: .leafWater
        )
    }

    /// Warm and wet is the classic root-rot window.
    private static func muggyTip(_ snapshot: WeatherSnapshot, _ shelf: Shelf) -> CareTip? {
        guard snapshot.temperatureC >= 20, snapshot.humidity >= 72 else { return nil }

        return CareTip(
            id: "muggy",
            title: "Hold off on watering",
            detail: "Soil dries slowly at \(snapshot.humidityText) humidity. "
                + shelf.list(shelf.succulents, fallback: "Cacti and succulents")
                + " rot far more easily than they dry out.",
            symbolName: "exclamationmark.triangle.fill",
            tint: .leafClay
        )
    }

    /// Short days mean less growth, so the usual feeding and watering cadence is too keen.
    private static func shortDayTip(_ snapshot: WeatherSnapshot, _ shelf: Shelf) -> CareTip? {
        guard snapshot.daylight > 0, snapshot.daylight < 10 * 3600 else { return nil }

        return CareTip(
            id: "short-day",
            title: "Only \(snapshot.daylightText) of daylight",
            detail: "Growth slows now. Move "
                + shelf.list(shelf.lightHungry, fallback: "the plants that like it brightest")
                + " closer to the window and feed less often.",
            symbolName: "sun.horizon.fill",
            tint: .leafGold
        )
    }
}

// MARK: - Shelf

/// Groups the user's plants by the care traits the rules above care about, matching on
/// whatever the user typed as a name or species.
private struct Shelf {
    let succulents: [String]
    let humidityLovers: [String]
    let thirsty: [String]
    let tender: [String]
    let lightHungry: [String]
    let hasOutdoorPlants: Bool

    init(plants: [Plant]) {
        func names(matching keywords: [String]) -> [String] {
            plants.filter { plant in
                let haystack = "\(plant.name) \(plant.species)".lowercased()
                return keywords.contains { haystack.contains($0) }
            }
            .map(\.name)
        }

        succulents = names(matching: [
            "succulent", "cactus", "cacti", "aloe", "echeveria", "echinopsis", "jade",
            "haworthia", "sedum", "snake plant", "sansevieria", "zz plant", "zamioculcas",
        ])

        humidityLovers = names(matching: [
            "calathea", "maranta", "fern", "alocasia", "orchid", "peace lily", "spathiphyllum",
            "anthurium", "prayer plant", "stromanthe",
        ])

        // A plant with a short watering interval is thirsty by definition, whatever it is called.
        thirsty = plants
            .filter { $0.wateringIntervalDays <= 8 }
            .map(\.name)

        tender = names(matching: [
            "monstera", "calathea", "fern", "alocasia", "philodendron", "ficus", "fiddle",
            "orchid", "peace lily", "anthurium", "palm", "pothos",
        ])

        lightHungry = names(matching: [
            "fiddle", "ficus", "monstera", "cactus", "succulent", "aloe", "citrus",
            "hibiscus", "olive", "basil", "herb",
        ])

        hasOutdoorPlants = plants.contains {
            let room = $0.room.lowercased()
            return room.contains("balcony") || room.contains("terrace") || room.contains("garden")
        }
    }

    /// "Spiky", "Spiky and Aloe", "Spiky, Aloe and 2 more" — never a runaway list.
    func list(_ names: [String], fallback: String = "Your plants") -> String {
        switch names.count {
        case 0: fallback
        case 1: names[0]
        case 2: "\(names[0]) and \(names[1])"
        default: "\(names[0]), \(names[1]) and \(names.count - 2) more"
        }
    }
}
