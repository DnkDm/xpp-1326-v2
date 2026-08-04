import Foundation

/// A single care task a plant owes on a given day.
struct CareTask: Identifiable {
    let plant: Plant
    let kind: CareKind
    let dueDate: Date

    /// Stable across recomputation, so view state keyed by task survives a redraw.
    var id: String { "\(plant.id.uuidString)-\(kind.rawValue)" }

    func isOverdue(on date: Date = .now, calendar: Calendar = .current) -> Bool {
        dueDate < calendar.startOfDay(for: date)
    }
}

/// One dot on the calendar: either a scheduled task or a logged one.
struct CareOccurrence: Identifiable {
    let id = UUID()
    let plant: Plant
    let kind: CareKind
    let isCompleted: Bool
}

/// Turns plant schedules into the lists the Today and Calendar screens render.
enum CareSchedule {
    /// Tasks due on or before `date`, most overdue first.
    static func dueTasks(
        for plants: [Plant],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> [CareTask] {
        let today = calendar.startOfDay(for: date)
        return plants
            .flatMap { plant in
                CareKind.allCases.compactMap { kind -> CareTask? in
                    let due = plant.dueDate(for: kind, calendar: calendar)
                    guard due <= today else { return nil }
                    return CareTask(plant: plant, kind: kind, dueDate: due)
                }
            }
            .sorted { lhs, rhs in
                lhs.dueDate == rhs.dueDate ? lhs.plant.name < rhs.plant.name : lhs.dueDate < rhs.dueDate
            }
    }

    /// Care logged on a given day, newest first.
    static func log(
        for plants: [Plant],
        on date: Date = .now,
        calendar: Calendar = .current
    ) -> [CareLogEntry] {
        plants
            .flatMap(\.careLog)
            .filter { calendar.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date > $1.date }
    }

    /// Everything that happens in `month`, bucketed by day so a calendar cell is an O(1) lookup.
    ///
    /// Upcoming tasks repeat forward at each plant's interval, so the month shows the real
    /// rhythm of care rather than a single next date.
    static func occurrencesByDay(
        for plants: [Plant],
        in month: DateInterval,
        calendar: Calendar = .current
    ) -> [Date: [CareOccurrence]] {
        var result: [Date: [CareOccurrence]] = [:]

        for plant in plants {
            for entry in plant.careLog where month.contains(entry.date) {
                let day = calendar.startOfDay(for: entry.date)
                result[day, default: []].append(
                    CareOccurrence(plant: plant, kind: entry.kind, isCompleted: true)
                )
            }

            for kind in CareKind.allCases {
                for day in occurrences(of: kind, for: plant, in: month, calendar: calendar) {
                    result[day, default: []].append(
                        CareOccurrence(plant: plant, kind: kind, isCompleted: false)
                    )
                }
            }
        }

        return result
    }

    private static func occurrences(
        of kind: CareKind,
        for plant: Plant,
        in month: DateInterval,
        calendar: Calendar
    ) -> [Date] {
        let step = max(plant.interval(for: kind), 1)
        var day = plant.dueDate(for: kind, calendar: calendar)
        var days: [Date] = []

        // A tight interval over a long-past anchor could otherwise spin for a long time.
        let maxIterations = 400
        var iterations = 0

        while day < month.start, iterations < maxIterations {
            guard let next = calendar.date(byAdding: .day, value: step, to: day) else { break }
            day = next
            iterations += 1
        }

        while day <= month.end, iterations < maxIterations {
            days.append(day)
            guard let next = calendar.date(byAdding: .day, value: step, to: day) else { break }
            day = next
            iterations += 1
        }

        return days
    }
}
