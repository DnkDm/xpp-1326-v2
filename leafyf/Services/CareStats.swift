import Foundation

/// Turns care history into the numbers the Insights screen charts.
///
/// Everything here is a pure function over `[Plant]` with the calendar and "now" passed in,
/// so the same call renders identically in a preview, in a test and on device — and so the
/// screen itself stays a layout with no arithmetic hidden inside it.
enum CareStats {

    // MARK: - Weekly activity

    /// One stacked-bar segment: how many tasks of one kind were logged in one week.
    struct WeeklyCare: Identifiable, Hashable {
        let weekStart: Date
        let kind: CareKind
        let count: Int

        var id: String { "\(weekStart.timeIntervalSince1970)-\(kind.rawValue)" }
    }

    /// Logged care for the last `weeks` weeks, bucketed by week and kind.
    ///
    /// Empty weeks are kept (as zero-count rows for every kind) so the chart always spans the
    /// full window instead of collapsing around whichever weeks happen to have entries.
    static func weeklyActivity(
        for plants: [Plant],
        weeks: Int = 8,
        now: Date = .now,
        calendar: Calendar = .current
    ) -> [WeeklyCare] {
        let currentWeek = startOfWeek(for: now, calendar: calendar)
        let weekStarts: [Date] = (0..<weeks).reversed().compactMap {
            calendar.date(byAdding: .weekOfYear, value: -$0, to: currentWeek)
        }
        guard let earliest = weekStarts.first else { return [] }

        var counts: [Date: [CareKind: Int]] = [:]
        for plant in plants {
            for entry in plant.careLog where entry.date >= earliest {
                let week = startOfWeek(for: entry.date, calendar: calendar)
                counts[week, default: [:]][entry.kind, default: 0] += 1
            }
        }

        return weekStarts.flatMap { week in
            CareKind.allCases.map { kind in
                WeeklyCare(weekStart: week, kind: kind, count: counts[week]?[kind] ?? 0)
            }
        }
    }

    // MARK: - Rooms

    struct RoomCount: Identifiable, Hashable {
        let room: String
        let count: Int

        var id: String { room }
    }

    /// Plants per room, busiest room first so the bar chart reads top down.
    static func plantsByRoom(_ plants: [Plant]) -> [RoomCount] {
        Dictionary(grouping: plants) { $0.room.isEmpty ? Room.default : $0.room }
            .map { RoomCount(room: $0.key, count: $0.value.count) }
            .sorted { $0.count == $1.count ? $0.room < $1.room : $0.count > $1.count }
    }

    // MARK: - Moods

    struct MoodCount: Identifiable, Hashable {
        let mood: PlantMood
        let count: Int

        var id: String { mood.rawValue }
    }

    /// How the collection is doing right now. Moods with no plants are dropped so the
    /// donut has no invisible slices and the legend stays short.
    static func moodBreakdown(_ plants: [Plant]) -> [MoodCount] {
        PlantMood.allCases.compactMap { mood in
            let count = plants.filter { $0.mood == mood }.count
            return count == 0 ? nil : MoodCount(mood: mood, count: count)
        }
    }

    // MARK: - Streak

    /// Consecutive days with at least one logged task, counting back from today.
    ///
    /// A day with nothing logged yet does not break the streak — it has not finished — so the
    /// count starts at yesterday when today is still empty. That matches how people read a
    /// streak: it only resets once a whole day has gone by with no care at all.
    static func careStreak(
        for plants: [Plant],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let days = Set(plants.flatMap(\.careLog).map { calendar.startOfDay(for: $0.date) })
        guard !days.isEmpty else { return 0 }

        let today = calendar.startOfDay(for: now)
        var cursor = days.contains(today)
            ? today
            : calendar.date(byAdding: .day, value: -1, to: today) ?? today

        var streak = 0
        while days.contains(cursor) {
            streak += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return streak
    }

    // MARK: - Totals

    struct Totals: Hashable {
        let plants: Int
        let tasksThisMonth: Int
        /// Share of logged care that happened on or before its due date, or `nil` when
        /// nothing has been logged yet — which is different from a rate of zero.
        let onTimeRate: Double?
        let loggedTasks: Int
    }

    static func totals(
        for plants: [Plant],
        now: Date = .now,
        calendar: Calendar = .current
    ) -> Totals {
        let logs = plants.flatMap(\.careLog)
        let thisMonth = logs.filter { calendar.isDate($0.date, equalTo: now, toGranularity: .month) }

        return Totals(
            plants: plants.count,
            tasksThisMonth: thisMonth.count,
            onTimeRate: onTimeRate(for: plants, calendar: calendar),
            loggedTasks: logs.count
        )
    }

    /// Share of care logs that landed on or before the day they were due.
    ///
    /// Each entry is judged against the schedule as it stood at the time: the previous entry of
    /// the same kind plus the plant's interval, or the day the plant was added for the first one.
    static func onTimeRate(for plants: [Plant], calendar: Calendar = .current) -> Double? {
        var onTime = 0
        var total = 0

        for plant in plants {
            for kind in CareKind.allCases {
                let dates = plant.careLog.filter { $0.kind == kind }.map(\.date).sorted()
                var previous: Date?

                for date in dates {
                    let anchor = calendar.startOfDay(for: previous ?? plant.dateAdded)
                    let due = calendar.date(byAdding: .day, value: plant.interval(for: kind), to: anchor) ?? anchor

                    total += 1
                    if calendar.startOfDay(for: date) <= due { onTime += 1 }
                    previous = date
                }
            }
        }

        return total == 0 ? nil : Double(onTime) / Double(total)
    }

    // MARK: - Helpers

    private static func startOfWeek(for date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }
}
