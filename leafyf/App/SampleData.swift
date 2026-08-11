import SwiftData
import SwiftUI
import UIKit

/// Fills an empty store with a garden worth looking at, so the simulator shows real
/// layouts instead of empty states.
///
/// Debug simulator builds only — on a device, or in any release build, `seedIfNeeded`
/// compiles down to nothing. Add `-noSampleData` to the scheme's launch arguments to
/// start empty and check the first-run screens.
enum SampleData {
    static func seedIfNeeded(_ context: ModelContext) {
        #if DEBUG && targetEnvironment(simulator)
        guard !ProcessInfo.processInfo.arguments.contains("-noSampleData") else { return }
        guard (try? context.fetchCount(FetchDescriptor<Plant>())) == 0 else { return }

        for plant in makePlants() {
            context.insert(plant)
        }
        try? context.save()
        #endif
    }

    #if DEBUG && targetEnvironment(simulator)

    // MARK: - Plants

    /// One plant per mood, so every badge, colour and empty branch shows up somewhere.
    private static func makePlants() -> [Plant] {
        let monstera = Plant(
            name: "Big Monstera",
            species: "Monstera deliciosa",
            room: "Living room",
            notes: "Rotate a quarter turn every month so it grows evenly. Wipe the leaves when they look dusty — it sulks otherwise.",
            photo: photo(hue: 0.32, symbol: "leaf.fill"),
            wateringIntervalDays: 7,
            dateAdded: daysAgo(420)
        )
        monstera.lastWatered = daysAgo(11)
        monstera.lastFertilized = daysAgo(24)
        monstera.lastRepotted = daysAgo(300)

        let pothos = Plant(
            name: "Kitchen Pothos",
            species: "Epipremnum aureum",
            room: "Kitchen",
            notes: "Trailing over the shelf. Cuttings root in water in about two weeks.",
            photo: photo(hue: 0.28, symbol: "camera.macro"),
            wateringIntervalDays: 8,
            dateAdded: daysAgo(210)
        )
        pothos.lastWatered = daysAgo(8)
        pothos.lastFertilized = daysAgo(30)

        let fig = Plant(
            name: "Fig by the window",
            species: "Ficus lyrata",
            room: "Office",
            notes: "Hates being moved. Leave it where it is.",
            photo: photo(hue: 0.24, symbol: "tree.fill"),
            wateringIntervalDays: 9,
            dateAdded: daysAgo(150)
        )
        fig.lastWatered = daysAgo(8)
        fig.lastFertilized = daysAgo(14)

        let lily = Plant(
            name: "Peace Lily",
            species: "Spathiphyllum",
            room: "Bathroom",
            notes: "Droops dramatically when thirsty, then recovers within the hour.",
            photo: photo(hue: 0.42, symbol: "drop.fill"),
            wateringIntervalDays: 6,
            fertilizingIntervalDays: 21,
            dateAdded: daysAgo(95)
        )
        lily.lastWatered = daysAgo(4)
        lily.lastFertilized = daysAgo(40)

        let cactus = Plant(
            name: "Spiky",
            species: "Echinopsis",
            room: "Balcony",
            notes: "Full sun, almost no water in winter.",
            photo: photo(hue: 0.12, symbol: "sun.max.fill"),
            wateringIntervalDays: 21,
            fertilizingIntervalDays: 90,
            dateAdded: daysAgo(70)
        )
        cactus.lastWatered = daysAgo(5)
        cactus.lastFertilized = daysAgo(35)

        // No care logged yet — the "settling in" mood and the empty history card.
        let snake = Plant(
            name: "New Snake Plant",
            species: "Dracaena trifasciata",
            room: "Bedroom",
            photo: photo(hue: 0.20, symbol: "leaf.arrow.trianglehead.clockwise"),
            wateringIntervalDays: 14,
            dateAdded: daysAgo(3)
        )

        let plants = [monstera, pothos, fig, lily, cactus, snake]

        addHistory(to: monstera, waterEvery: 7, times: 9, fertilizeEvery: 28, times: 4)
        addHistory(to: pothos, waterEvery: 8, times: 7, fertilizeEvery: 30, times: 3)
        addHistory(to: fig, waterEvery: 9, times: 6, fertilizeEvery: 28, times: 2)
        addHistory(to: lily, waterEvery: 6, times: 8, fertilizeEvery: 21, times: 2)
        addHistory(to: cactus, waterEvery: 21, times: 3, fertilizeEvery: 90, times: 1)

        addJournal(to: monstera, hue: 0.32, entries: [
            (60, "Third fenestrated leaf of the year."),
            (28, "Repotted into the big terracotta pot."),
            (5, "New leaf unfurling on the left side."),
        ])
        addJournal(to: fig, hue: 0.24, entries: [
            (40, "Dropped two lower leaves after the move."),
            (9, "Growing again — four new leaves this month."),
        ])
        addJournal(to: lily, hue: 0.42, entries: [
            (14, "First flower since spring."),
        ])

        return plants
    }

    // MARK: - History

    /// Back-dated care entries so the history list and the calendar have something in them.
    private static func addHistory(
        to plant: Plant,
        waterEvery waterInterval: Int,
        times waterCount: Int,
        fertilizeEvery fertilizeInterval: Int,
        times fertilizeCount: Int
    ) {
        guard let lastWatered = plant.lastWatered else { return }

        for step in 0..<waterCount {
            log(.watering, on: daysBefore(step * waterInterval, from: lastWatered), for: plant)
        }

        if let lastFertilized = plant.lastFertilized {
            for step in 0..<fertilizeCount {
                log(.fertilizing, on: daysBefore(step * fertilizeInterval, from: lastFertilized), for: plant)
            }
        }

        if let lastRepotted = plant.lastRepotted {
            log(.repotting, on: lastRepotted, for: plant)
        }
    }

    private static func log(_ kind: CareKind, on date: Date, for plant: Plant) {
        let entry = CareLogEntry(kind: kind, date: date)
        entry.plant = plant
        plant.careLog.append(entry)
    }

    // MARK: - Journal

    private static func addJournal(to plant: Plant, hue: Double, entries: [(daysAgo: Int, caption: String)]) {
        for entry in entries {
            let journalEntry = JournalEntry(
                photo: photo(hue: hue, symbol: "leaf.fill"),
                caption: entry.caption,
                date: daysAgo(entry.daysAgo)
            )
            journalEntry.plant = plant
            plant.journal.append(journalEntry)
        }
    }

    // MARK: - Placeholder photos

    /// Drawn rather than bundled, so the sample garden costs the app no asset weight.
    private static func photo(hue: Double, symbol: String) -> ProcessedPhoto {
        ProcessedPhoto(
            full: render(side: 900, hue: hue, symbol: symbol),
            thumbnail: render(side: 240, hue: hue, symbol: symbol)
        )
    }

    private static func render(side: CGFloat, hue: Double, symbol: String) -> Data {
        let size = CGSize(width: side, height: side)

        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { context in
            let colors = [
                UIColor(hue: hue, saturation: 0.30, brightness: 0.80, alpha: 1).cgColor,
                UIColor(hue: hue, saturation: 0.55, brightness: 0.38, alpha: 1).cgColor,
            ]

            if let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) {
                context.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: side * 0.15, y: 0),
                    end: CGPoint(x: side * 0.85, y: side),
                    options: []
                )
            }

            let configuration = UIImage.SymbolConfiguration(pointSize: side * 0.34, weight: .light)
            guard let glyph = UIImage(systemName: symbol, withConfiguration: configuration)?
                .withTintColor(.white.withAlphaComponent(0.7), renderingMode: .alwaysOriginal)
            else { return }

            glyph.draw(
                in: CGRect(
                    x: (side - glyph.size.width) / 2,
                    y: (side - glyph.size.height) / 2,
                    width: glyph.size.width,
                    height: glyph.size.height
                )
            )
        }
    }

    // MARK: - Dates

    private static func daysAgo(_ days: Int) -> Date {
        daysBefore(days, from: .now)
    }

    private static func daysBefore(_ days: Int, from date: Date) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: date) ?? date
    }

    #endif
}
