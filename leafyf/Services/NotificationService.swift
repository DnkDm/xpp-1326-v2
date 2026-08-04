import Foundation
import UserNotifications

/// Schedules one local reminder per plant and care kind, at the user's preferred time of day.
@MainActor
final class NotificationService {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    @discardableResult
    func requestAuthorization() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Replaces every pending reminder for the given plants with a freshly computed set.
    func reschedule(for plants: [Plant]) async {
        guard !plants.isEmpty else { return }

        cancelReminders(forPlantIDs: plants.map(\.id))
        guard await authorizationStatus() == .authorized else { return }

        let time = ReminderTime.current
        for plant in plants where plant.remindersEnabled {
            for kind in CareKind.allCases {
                let request = makeRequest(for: plant, kind: kind, at: time)
                try? await center.add(request)
            }
        }
    }

    func cancelReminders(forPlantID id: UUID) {
        cancelReminders(forPlantIDs: [id])
    }

    private func cancelReminders(forPlantIDs ids: [UUID]) {
        let identifiers = ids.flatMap { id in
            CareKind.allCases.map { identifier(plantID: id, kind: $0) }
        }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func makeRequest(for plant: Plant, kind: CareKind, at time: ReminderTime) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title(for: kind, plantName: plant.name)
        content.body = body(for: kind, plantName: plant.name)
        content.sound = .default
        content.userInfo = ["plantID": plant.id.uuidString, "careKind": kind.rawValue]

        let fireDate = nextFireDate(dueDay: plant.dueDate(for: kind), at: time)
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        return UNNotificationRequest(
            identifier: identifier(plantID: plant.id, kind: kind),
            content: content,
            trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        )
    }

    /// An overdue task would otherwise never fire, so it rolls forward to the next reminder slot.
    private func nextFireDate(
        dueDay: Date,
        at time: ReminderTime,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Date {
        let scheduled = time.applied(to: dueDay, calendar: calendar)
        if scheduled > now { return scheduled }

        let todaySlot = time.applied(to: now, calendar: calendar)
        if todaySlot > now { return todaySlot }

        return calendar.date(byAdding: .day, value: 1, to: todaySlot) ?? todaySlot
    }

    private func identifier(plantID: UUID, kind: CareKind) -> String {
        "care-\(plantID.uuidString)-\(kind.rawValue)"
    }

    private func title(for kind: CareKind, plantName: String) -> String {
        switch kind {
        case .watering: "Time to water \(plantName) 💧"
        case .fertilizing: "Feed \(plantName) 🌿"
        case .repotting: "\(plantName) needs a bigger pot 🪴"
        }
    }

    private func body(for kind: CareKind, plantName: String) -> String {
        switch kind {
        case .watering: "The soil should be dry by now."
        case .fertilizing: "A round of nutrients keeps new growth coming."
        case .repotting: "Roots have had a year to fill the pot."
        }
    }
}
