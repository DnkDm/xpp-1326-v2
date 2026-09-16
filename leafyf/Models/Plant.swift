import Foundation
import SwiftData
import SwiftUI

@Model
final class Plant {
    @Attribute(.unique) var id: UUID
    var name: String
    var species: String
    var room: String
    var notes: String
    var dateAdded: Date
    var remindersEnabled: Bool

    /// Full-size photo, kept out of the store file because it is only shown on the detail screen.
    @Attribute(.externalStorage) var photoData: Data?
    /// Small copy used by lists, so scrolling never decodes a full-size image.
    var thumbnailData: Data?

    var wateringIntervalDays: Int
    var fertilizingIntervalDays: Int
    var repottingIntervalDays: Int

    var lastWatered: Date?
    var lastFertilized: Date?
    var lastRepotted: Date?

    @Relationship(deleteRule: .cascade, inverse: \CareLogEntry.plant)
    var careLog: [CareLogEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \JournalEntry.plant)
    var journal: [JournalEntry] = []

    init(
        name: String,
        species: String = "",
        room: String = Room.default,
        notes: String = "",
        remindersEnabled: Bool = true,
        photo: ProcessedPhoto? = nil,
        wateringIntervalDays: Int = CareKind.watering.defaultIntervalDays,
        fertilizingIntervalDays: Int = CareKind.fertilizing.defaultIntervalDays,
        repottingIntervalDays: Int = CareKind.repotting.defaultIntervalDays,
        dateAdded: Date = .now
    ) {
        self.id = UUID()
        self.name = name
        self.species = species
        self.room = room
        self.notes = notes
        self.remindersEnabled = remindersEnabled
        self.photoData = photo?.full
        self.thumbnailData = photo?.thumbnail
        self.wateringIntervalDays = wateringIntervalDays
        self.fertilizingIntervalDays = fertilizingIntervalDays
        self.repottingIntervalDays = repottingIntervalDays
        self.dateAdded = dateAdded
    }
}

// MARK: - Care schedule

extension Plant {
    func interval(for kind: CareKind) -> Int {
        switch kind {
        case .watering: wateringIntervalDays
        case .fertilizing: fertilizingIntervalDays
        case .repotting: repottingIntervalDays
        }
    }

    func setInterval(_ days: Int, for kind: CareKind) {
        let clamped = min(max(days, kind.intervalRange.lowerBound), kind.intervalRange.upperBound)
        switch kind {
        case .watering: wateringIntervalDays = clamped
        case .fertilizing: fertilizingIntervalDays = clamped
        case .repotting: repottingIntervalDays = clamped
        }
    }

    func lastCareDate(for kind: CareKind) -> Date? {
        switch kind {
        case .watering: lastWatered
        case .fertilizing: lastFertilized
        case .repotting: lastRepotted
        }
    }

    func setLastCareDate(_ date: Date?, for kind: CareKind) {
        switch kind {
        case .watering: lastWatered = date
        case .fertilizing: lastFertilized = date
        case .repotting: lastRepotted = date
        }
    }

    /// The day the next task of this kind falls due.
    ///
    /// Anchored on the last logged care, or — when nothing has been logged yet — on the day
    /// the plant was added, so a brand-new plant still gets its first reminder.
    func dueDate(for kind: CareKind, calendar: Calendar = .current) -> Date {
        let anchor = calendar.startOfDay(for: lastCareDate(for: kind) ?? dateAdded)
        return calendar.date(byAdding: .day, value: interval(for: kind), to: anchor) ?? anchor
    }

    /// Days from today until the task is due. Negative when it is overdue.
    func daysUntilDue(for kind: CareKind, from date: Date = .now, calendar: Calendar = .current) -> Int {
        calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: date),
            to: dueDate(for: kind, calendar: calendar)
        ).day ?? 0
    }

    /// How far the plant is through its current interval, from 0 (just cared for) to 1 (due).
    func progress(for kind: CareKind, from date: Date = .now, calendar: Calendar = .current) -> Double {
        let total = Double(interval(for: kind))
        guard total > 0 else { return 1 }
        let remaining = Double(daysUntilDue(for: kind, from: date, calendar: calendar))
        return min(max((total - remaining) / total, 0), 1)
    }

    func statusText(for kind: CareKind, from date: Date = .now, calendar: Calendar = .current) -> String {
        let days = daysUntilDue(for: kind, from: date, calendar: calendar)
        return switch days {
        case ..<0: "\(Format.days(-days)) overdue"
        case 0: "Due today"
        case 1: "Due tomorrow"
        default: "Due in \(Format.days(days))"
        }
    }

    /// The one rule for "how urgent is this task", shared by every place that colours a
    /// schedule — status lines, care rings, detail rows — so the same plant never reads as
    /// two different degrees of urgency on two screens.
    func urgencyTint(for kind: CareKind, from date: Date = .now, calendar: Calendar = .current) -> Color {
        switch daysUntilDue(for: kind, from: date, calendar: calendar) {
        case ..<0: .leafClay
        case 0: .leafGold
        default: kind.tint
        }
    }

    var mood: PlantMood {
        let days = CareKind.allCases.map { daysUntilDue(for: $0) }
        if days.contains(where: { $0 < 0 }) { return .overdue }
        if days.contains(0) { return .dueToday }
        let hasHistory = CareKind.allCases.contains { lastCareDate(for: $0) != nil }
        return hasHistory ? .thriving : .settlingIn
    }

    var displaySpecies: String { species.isEmpty ? "Houseplant" : species }
}

// MARK: - Rooms

enum Room {
    static let presets = [
        "Living room", "Bedroom", "Kitchen", "Office", "Balcony", "Bathroom", "Hallway",
    ]

    static let `default` = "Living room"
}
