import SwiftUI

/// The bundled illustration for a species, when Leafy ships one.
///
/// Twenty illustrations cover the most common houseplants plus a generic one; every other
/// species and every plant with an unrecognised species name falls back to the generic
/// image, so a plant without a photo of its own never shows an empty tile.
enum SpeciesArtwork {
    static let genericImageName = "species-houseplant"

    /// Common names that have a dedicated illustration, keyed by asset slug.
    private static let slugsByName: [String: String] = [
        "monstera": "monstera",
        "pothos": "pothos",
        "snake plant": "snake-plant",
        "fiddle leaf fig": "fiddle-leaf-fig",
        "peace lily": "peace-lily",
        "orchid": "orchid",
        "aloe vera": "aloe-vera",
        "cactus": "cactus",
        "calathea": "calathea",
        "zz plant": "zz-plant",
        "spider plant": "spider-plant",
        "rubber plant": "rubber-plant",
        "chinese money plant": "chinese-money-plant",
        "jade plant": "jade-plant",
        "boston fern": "boston-fern",
        "string of pearls": "string-of-pearls",
        "heartleaf philodendron": "heartleaf-philodendron",
        "bird of paradise": "bird-of-paradise",
        "areca palm": "areca-palm",
    ]

    /// The dedicated illustration for a catalog species, or nil when it only has the generic one.
    static func imageName(for species: PlantSpecies) -> String? {
        slugsByName[species.name.lowercased()].map { "species-\($0)" }
    }

    /// Best illustration for a free-text species string as typed on a plant: matches the
    /// catalog by common or botanical name (either direction of "contains", so
    /// "Monstera deliciosa" finds Monstera and "Snake" finds Snake Plant), else generic.
    static func imageName(forSpeciesText text: String) -> String {
        let needle = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return genericImageName }

        let match = PlantSpecies.catalog.first { species in
            let common = species.name.lowercased()
            let latin = species.scientificName.lowercased()
            return needle == common || needle == latin
                || needle.contains(common) || needle.contains(latin)
                || (needle.count >= 4 && (common.contains(needle) || latin.contains(needle)))
        }

        return match.flatMap { imageName(for: $0) } ?? genericImageName
    }
}

extension PlantSpecies {
    /// Illustration to show for this species: its own when it has one, else the generic plant.
    var artworkName: String {
        SpeciesArtwork.imageName(for: self) ?? SpeciesArtwork.genericImageName
    }

    var hasOwnArtwork: Bool {
        SpeciesArtwork.imageName(for: self) != nil
    }
}

extension Plant {
    /// Illustration used wherever the plant has no photo of its own.
    var artworkName: String {
        SpeciesArtwork.imageName(forSpeciesText: species)
    }
}
