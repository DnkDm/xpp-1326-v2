import Foundation

/// A starting point for a new plant: sensible care intervals plus a short care note.
struct PlantSpecies: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let emoji: String
    let light: String
    let summary: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let repottingIntervalDays: Int

    init(
        name: String,
        emoji: String,
        light: String,
        summary: String,
        watering: Int,
        fertilizing: Int,
        repotting: Int = 365
    ) {
        self.id = name
        self.name = name
        self.emoji = emoji
        self.light = light
        self.summary = summary
        self.wateringIntervalDays = watering
        self.fertilizingIntervalDays = fertilizing
        self.repottingIntervalDays = repotting
    }
}

extension PlantSpecies {
    static let catalog: [PlantSpecies] = [
        PlantSpecies(
            name: "Monstera",
            emoji: "🌿",
            light: "Bright indirect",
            summary: "Tropical climber with iconic split leaves. Let the top soil dry between waterings.",
            watering: 7,
            fertilizing: 30
        ),
        PlantSpecies(
            name: "Pothos",
            emoji: "🍃",
            light: "Low to moderate",
            summary: "Trailing vine that forgives almost everything. Ideal first plant.",
            watering: 7,
            fertilizing: 30
        ),
        PlantSpecies(
            name: "Snake Plant",
            emoji: "🌱",
            light: "Low to bright",
            summary: "Nearly indestructible. Far happier under-watered than over-watered.",
            watering: 14,
            fertilizing: 60,
            repotting: 730
        ),
        PlantSpecies(
            name: "Fiddle Leaf Fig",
            emoji: "🌳",
            light: "Bright indirect",
            summary: "Dramatic indoor tree. Keep it away from cold drafts and rotate it monthly.",
            watering: 7,
            fertilizing: 30
        ),
        PlantSpecies(
            name: "Peace Lily",
            emoji: "🤍",
            light: "Low to moderate",
            summary: "Elegant white blooms. Visibly droops when thirsty, then perks right back up.",
            watering: 6,
            fertilizing: 30
        ),
        PlantSpecies(
            name: "Orchid",
            emoji: "🌸",
            light: "Bright indirect",
            summary: "Grows in bark, not soil. Soak, then let it dry out completely.",
            watering: 7,
            fertilizing: 14,
            repotting: 730
        ),
        PlantSpecies(
            name: "Aloe Vera",
            emoji: "🪴",
            light: "Full sun",
            summary: "Succulent that stores its own water. Drench rarely, drain thoroughly.",
            watering: 14,
            fertilizing: 60,
            repotting: 730
        ),
        PlantSpecies(
            name: "Cactus",
            emoji: "🌵",
            light: "Full sun",
            summary: "Desert native. In winter it can go a month between drinks.",
            watering: 21,
            fertilizing: 90,
            repotting: 1095
        ),
        PlantSpecies(
            name: "Calathea",
            emoji: "🎋",
            light: "Medium indirect",
            summary: "Loves humidity and hates hard water. Mist or use filtered water.",
            watering: 5,
            fertilizing: 30
        ),
        PlantSpecies(
            name: "ZZ Plant",
            emoji: "🌾",
            light: "Low to bright",
            summary: "Thrives on neglect and low light. Water only when the soil is bone dry.",
            watering: 18,
            fertilizing: 60,
            repotting: 730
        ),
    ]
}
