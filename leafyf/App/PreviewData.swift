import SwiftData
import SwiftUI

/// In-memory sample data so every `#Preview` renders a populated app.
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

    private static func makePlants() -> [Plant] {
        let calendar = Calendar.current

        func daysAgo(_ days: Int) -> Date {
            calendar.date(byAdding: .day, value: -days, to: .now) ?? .now
        }

        let monstera = Plant(
            name: "Big Monstera",
            species: "Monstera deliciosa",
            room: "Living room",
            notes: "Rotate a quarter turn every month so it grows evenly.",
            dateAdded: daysAgo(120)
        )
        monstera.lastWatered = daysAgo(9)
        monstera.lastFertilized = daysAgo(20)

        let pothos = Plant(
            name: "Kitchen Pothos",
            species: "Epipremnum aureum",
            room: "Kitchen",
            dateAdded: daysAgo(60)
        )
        pothos.lastWatered = daysAgo(7)

        let cactus = Plant(
            name: "Spiky",
            species: "Echinopsis",
            room: "Balcony",
            wateringIntervalDays: 21,
            fertilizingIntervalDays: 90,
            dateAdded: daysAgo(30)
        )
        cactus.lastWatered = daysAgo(3)

        for plant in [monstera, pothos, cactus] {
            let entry = CareLogEntry(kind: .watering, date: plant.lastWatered ?? .now)
            entry.plant = plant
            plant.careLog.append(entry)
        }

        return [monstera, pothos, cactus]
    }
}
