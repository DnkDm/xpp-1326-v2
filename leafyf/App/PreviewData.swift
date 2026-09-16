import SwiftData
import SwiftUI
import UIKit

/// In-memory sample data so every `#Preview` renders a populated app.
///
/// The care history goes back eight weeks with a deliberate mix of on-time and late entries,
/// because an Insights chart built from three log rows says nothing about whether the layout works.
@MainActor
enum PreviewData {
    static let container: ModelContainer = {
        let container = try! ModelContainer(
            for: Plant.self, CareLogEntry.self, JournalEntry.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )

        for plant in makePlants() {
            container.mainContext.insert(plant)
        }

        return container
    }()

    static var samplePlant: Plant {
        let descriptor = FetchDescriptor<Plant>(sortBy: [SortDescriptor(\.name)])
        return (try? container.mainContext.fetch(descriptor).first) ?? Plant(name: "Monstera")
    }

    static var sampleJournalEntry: JournalEntry {
        let descriptor = FetchDescriptor<JournalEntry>(sortBy: [SortDescriptor(\.date, order: .reverse)])
        return (try? container.mainContext.fetch(descriptor).first)
            ?? JournalEntry(photo: photo(hue: 0.32), caption: "New leaf")
    }

    // MARK: - Plants

    private static func makePlants() -> [Plant] {
        let monstera = Plant(
            name: "Big Monstera",
            species: "Monstera deliciosa",
            room: "Living room",
            notes: "Rotate a quarter turn every month so it grows evenly.",
            photo: photo(hue: 0.32),
            dateAdded: daysAgo(120)
        )
        monstera.lastWatered = daysAgo(9)
        monstera.lastFertilized = daysAgo(20)

        let pothos = Plant(
            name: "Kitchen Pothos",
            species: "Epipremnum aureum",
            room: "Kitchen",
            photo: photo(hue: 0.28),
            dateAdded: daysAgo(60)
        )
        pothos.lastWatered = daysAgo(7)
        pothos.lastFertilized = daysAgo(26)

        let cactus = Plant(
            name: "Spiky",
            species: "Echinopsis",
            room: "Balcony",
            photo: photo(hue: 0.12),
            wateringIntervalDays: 21,
            fertilizingIntervalDays: 90,
            dateAdded: daysAgo(30)
        )
        cactus.lastWatered = daysAgo(3)

        for plant in [monstera, pothos, cactus] {
            backfill(.watering, for: plant)
            backfill(.fertilizing, for: plant)
        }

        addJournal(to: monstera, hue: 0.32, entries: [
            (34, "Third fenestrated leaf of the year."),
            (12, "Repotted into the big terracotta pot."),
            (2, "New leaf unfurling on the left side."),
        ])
        addJournal(to: pothos, hue: 0.28, entries: [
            (20, "Cuttings rooted in about two weeks."),
        ])

        return [monstera, pothos, cactus]
    }

    // MARK: - History

    /// Walks backwards from the plant's last care date at its own cadence, nudged by a
    /// repeating pattern of delays so the on-time rate lands somewhere believable.
    private static func backfill(_ kind: CareKind, for plant: Plant, weeks: Int = 8) {
        guard let last = plant.lastCareDate(for: kind) else { return }

        let delays = [0, 2, -1, 0, 3, 1, 0, -2]
        let earliest = daysAgo(weeks * 7)
        var date = last
        var step = 0

        while date >= earliest {
            let entry = CareLogEntry(kind: kind, date: date)
            entry.plant = plant
            plant.careLog.append(entry)

            let gap = max(plant.interval(for: kind) + delays[step % delays.count], 1)
            date = daysBefore(gap, from: date)
            step += 1
        }
    }

    // MARK: - Journal

    private static func addJournal(to plant: Plant, hue: Double, entries: [(daysAgo: Int, caption: String)]) {
        for entry in entries {
            let journalEntry = JournalEntry(
                photo: photo(hue: hue),
                caption: entry.caption,
                date: daysAgo(entry.daysAgo)
            )
            journalEntry.plant = plant
            plant.journal.append(journalEntry)
        }
    }

    // MARK: - Placeholder photos

    /// Drawn rather than bundled: previews want a photo-shaped rectangle with colour in it,
    /// and a gradient costs the app no asset weight.
    private static func photo(hue: Double) -> ProcessedPhoto {
        let full = render(side: 480, hue: hue)
        return ProcessedPhoto(full: full, thumbnail: render(side: 160, hue: hue))
    }

    private static func render(side: CGFloat, hue: Double) -> Data {
        let size = CGSize(width: side, height: side)

        return UIGraphicsImageRenderer(size: size).jpegData(withCompressionQuality: 0.8) { context in
            let colors = [
                UIColor(hue: hue, saturation: 0.30, brightness: 0.80, alpha: 1).cgColor,
                UIColor(hue: hue, saturation: 0.55, brightness: 0.38, alpha: 1).cgColor,
            ]

            guard let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: colors as CFArray,
                locations: [0, 1]
            ) else { return }

            context.cgContext.drawLinearGradient(
                gradient,
                start: CGPoint(x: side * 0.15, y: 0),
                end: CGPoint(x: side * 0.85, y: side),
                options: []
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
}
