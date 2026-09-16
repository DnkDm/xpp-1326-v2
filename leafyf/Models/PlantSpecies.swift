import Foundation

/// A starting point for a new plant: sensible care intervals plus a short care note.
struct PlantSpecies: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    /// Botanical name, shown under the common one and used as the form's species field.
    let scientificName: String
    let emoji: String
    let light: String
    let summary: String
    let wateringIntervalDays: Int
    let fertilizingIntervalDays: Int
    let repottingIntervalDays: Int
    /// Exact English Wikipedia article title, so Explore can fetch a summary without
    /// guessing at the spelling. Defaults to the common name.
    let wikipediaTitle: String

    /// `scientificName` and `wikipediaTitle` fall back to the common name when they are
    /// left out, which keeps every earlier call site compiling unchanged.
    init(
        name: String,
        scientificName: String = "",
        emoji: String,
        light: String,
        summary: String,
        watering: Int,
        fertilizing: Int,
        repotting: Int = 365,
        wikipedia: String = ""
    ) {
        self.id = name
        self.name = name
        self.scientificName = scientificName.isEmpty ? name : scientificName
        self.emoji = emoji
        self.light = light
        self.summary = summary
        self.wateringIntervalDays = watering
        self.fertilizingIntervalDays = fertilizing
        self.repottingIntervalDays = repotting
        self.wikipediaTitle = wikipedia.isEmpty ? (scientificName.isEmpty ? name : scientificName) : wikipedia
    }
}

// MARK: - Catalog

extension PlantSpecies {
    /// The species Leafy knows about, ordered roughly from "everyone owns one" to
    /// "you went looking for it". Intervals are growing-season guidance for an average
    /// indoor pot; the library screen says as much.
    static let catalog: [PlantSpecies] = [
        PlantSpecies(
            name: "Monstera",
            scientificName: "Monstera deliciosa",
            emoji: "🌿",
            light: "Bright indirect",
            summary: "Tropical climber with iconic split leaves. Let the top soil dry between waterings.",
            watering: 7,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Pothos",
            scientificName: "Epipremnum aureum",
            emoji: "🍃",
            light: "Low to moderate",
            summary: "Trailing vine that forgives almost everything. Ideal first plant.",
            watering: 7,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Snake Plant",
            scientificName: "Dracaena trifasciata",
            emoji: "🌱",
            light: "Low to bright",
            summary: "Nearly indestructible. Far happier under-watered than over-watered.",
            watering: 14,
            fertilizing: 60,
            repotting: 730
        ),
        PlantSpecies(
            name: "Fiddle Leaf Fig",
            scientificName: "Ficus lyrata",
            emoji: "🌳",
            light: "Bright indirect",
            summary: "Dramatic indoor tree. Keep it away from cold drafts and rotate it monthly.",
            watering: 7,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Peace Lily",
            scientificName: "Spathiphyllum wallisii",
            emoji: "🤍",
            light: "Low to moderate",
            summary: "Elegant white blooms. Visibly droops when thirsty, then perks right back up.",
            watering: 6,
            fertilizing: 30,
            wikipedia: "Spathiphyllum"
        ),
        PlantSpecies(
            name: "Orchid",
            scientificName: "Phalaenopsis",
            emoji: "🌸",
            light: "Bright indirect",
            summary: "Grows in bark, not soil. Soak, then let it dry out completely.",
            watering: 7,
            fertilizing: 14,
            repotting: 730
        ),
        PlantSpecies(
            name: "Aloe Vera",
            scientificName: "Aloe vera",
            emoji: "🪴",
            light: "Full sun",
            summary: "Succulent that stores its own water. Drench rarely, drain thoroughly.",
            watering: 14,
            fertilizing: 60,
            repotting: 730
        ),
        PlantSpecies(
            name: "Cactus",
            scientificName: "Cactaceae",
            emoji: "🌵",
            light: "Full sun",
            summary: "Desert native. In winter it can go a month between drinks.",
            watering: 21,
            fertilizing: 90,
            repotting: 1095,
            wikipedia: "Cactus"
        ),
        PlantSpecies(
            name: "Calathea",
            scientificName: "Goeppertia",
            emoji: "🎋",
            light: "Medium indirect",
            summary: "Loves humidity and hates hard water. Mist or use filtered water.",
            watering: 5,
            fertilizing: 30,
            repotting: 730,
            wikipedia: "Calathea"
        ),
        PlantSpecies(
            name: "ZZ Plant",
            scientificName: "Zamioculcas zamiifolia",
            emoji: "🌾",
            light: "Low to bright",
            summary: "Thrives on neglect and low light. Water only when the soil is bone dry.",
            watering: 18,
            fertilizing: 60,
            repotting: 730,
            wikipedia: "Zamioculcas"
        ),
        PlantSpecies(
            name: "Spider Plant",
            scientificName: "Chlorophytum comosum",
            emoji: "🕸️",
            light: "Bright indirect",
            summary: "Throws out baby plantlets you can pot up. Brown tips mean hard water.",
            watering: 7,
            fertilizing: 30,
            repotting: 365
        ),
        PlantSpecies(
            name: "Rubber Plant",
            scientificName: "Ficus elastica",
            emoji: "🌲",
            light: "Bright indirect",
            summary: "Glossy burgundy leaves. Wipe the dust off them and it grows noticeably faster.",
            watering: 9,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Chinese Money Plant",
            scientificName: "Pilea peperomioides",
            emoji: "🪙",
            light: "Bright indirect",
            summary: "Round pancake leaves. Turn it weekly or it leans hard towards the window.",
            watering: 7,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Jade Plant",
            scientificName: "Crassula ovata",
            emoji: "💎",
            light: "Full sun",
            summary: "Tree-shaped succulent that can outlive you. Wrinkled leaves mean thirsty.",
            watering: 18,
            fertilizing: 60,
            repotting: 1095
        ),
        PlantSpecies(
            name: "Boston Fern",
            scientificName: "Nephrolepis exaltata",
            emoji: "🌿",
            light: "Medium indirect",
            summary: "Wants constantly damp soil and humid air. A bathroom suits it perfectly.",
            watering: 4,
            fertilizing: 30,
            repotting: 365
        ),
        PlantSpecies(
            name: "String of Pearls",
            scientificName: "Curio rowleyanus",
            emoji: "📿",
            light: "Bright indirect",
            summary: "Trailing beads that rot in a heartbeat. Water only when they start to flatten.",
            watering: 16,
            fertilizing: 60,
            repotting: 730
        ),
        PlantSpecies(
            name: "Heartleaf Philodendron",
            scientificName: "Philodendron hederaceum",
            emoji: "💚",
            light: "Low to bright indirect",
            summary: "Fast, forgiving trailer. Pinch the tips back to keep it full rather than leggy.",
            watering: 7,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Bird of Paradise",
            scientificName: "Strelitzia reginae",
            emoji: "🦜",
            light: "Full sun",
            summary: "Big architectural leaves. Split edges are normal, not a problem to fix.",
            watering: 8,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Areca Palm",
            scientificName: "Dypsis lutescens",
            emoji: "🌴",
            light: "Bright indirect",
            summary: "Thirsty feathery palm. Keep it evenly moist and away from radiators.",
            watering: 6,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Parlour Palm",
            scientificName: "Chamaedorea elegans",
            emoji: "🎍",
            light: "Low to medium",
            summary: "Happy in the dim corner most plants sulk in. Slow, tidy and undemanding.",
            watering: 8,
            fertilizing: 45,
            repotting: 730
        ),
        PlantSpecies(
            name: "Dragon Tree",
            scientificName: "Dracaena marginata",
            emoji: "🐉",
            light: "Medium to bright",
            summary: "Spiky crown on a slim trunk. Sensitive to fluoride, so use filtered water.",
            watering: 12,
            fertilizing: 45,
            repotting: 730
        ),
        PlantSpecies(
            name: "Dieffenbachia",
            scientificName: "Dieffenbachia seguine",
            emoji: "🌼",
            light: "Medium indirect",
            summary: "Big speckled leaves. Sap irritates, so keep it clear of pets and children.",
            watering: 8,
            fertilizing: 30,
            repotting: 730,
            wikipedia: "Dieffenbachia"
        ),
        PlantSpecies(
            name: "Croton",
            scientificName: "Codiaeum variegatum",
            emoji: "🍁",
            light: "Bright direct",
            summary: "Colour comes from strong light. It drops leaves whenever you move it.",
            watering: 6,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Anthurium",
            scientificName: "Anthurium andraeanum",
            emoji: "❤️",
            light: "Bright indirect",
            summary: "Waxy red spathes for months on end. Feed lightly but often while flowering.",
            watering: 6,
            fertilizing: 21,
            repotting: 730,
            wikipedia: "Anthurium"
        ),
        PlantSpecies(
            name: "African Violet",
            scientificName: "Saintpaulia",
            emoji: "💜",
            light: "Bright indirect",
            summary: "Water from below — droplets on the fuzzy leaves leave permanent marks.",
            watering: 5,
            fertilizing: 21,
            repotting: 365
        ),
        PlantSpecies(
            name: "English Ivy",
            scientificName: "Hedera helix",
            emoji: "🍀",
            light: "Medium indirect",
            summary: "Cool rooms and moist soil suit it. Check regularly for spider mites.",
            watering: 6,
            fertilizing: 30,
            repotting: 365
        ),
        PlantSpecies(
            name: "Prayer Plant",
            scientificName: "Maranta leuconeura",
            emoji: "🙏",
            light: "Medium indirect",
            summary: "Folds its leaves up at night. Needs humidity and never quite dry soil.",
            watering: 5,
            fertilizing: 30,
            repotting: 730
        ),
        PlantSpecies(
            name: "Christmas Cactus",
            scientificName: "Schlumbergera",
            emoji: "🎄",
            light: "Bright indirect",
            summary: "A jungle cactus, not a desert one. Cool dark autumn nights set the buds.",
            watering: 12,
            fertilizing: 45,
            repotting: 1095
        ),
    ]
}
