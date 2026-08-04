import Foundation
import SwiftData

/// The one place that records care, so every screen logs history and reschedules
/// reminders the same way.
enum PlantCare {
    static func log(
        _ kind: CareKind,
        for plant: Plant,
        in context: ModelContext,
        on date: Date = .now,
        note: String = ""
    ) {
        plant.setLastCareDate(date, for: kind)

        let entry = CareLogEntry(kind: kind, date: date, note: note)
        entry.plant = plant
        context.insert(entry)

        Task { await NotificationService.shared.reschedule(for: [plant]) }
    }

    static func delete(_ plant: Plant, from context: ModelContext) {
        NotificationService.shared.cancelReminders(forPlantID: plant.id)
        context.delete(plant)
    }
}
