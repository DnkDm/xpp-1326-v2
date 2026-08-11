import SwiftData
import SwiftUI

struct CareCalendarView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Plant.name) private var plants: [Plant]

    @State private var visibleMonth = Calendar.current.startOfMonth(for: .now)
    @State private var selectedDay = Calendar.current.startOfDay(for: .now)

    private let calendar = Calendar.current

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: visibleMonth)
            ?? DateInterval(start: visibleMonth, duration: 0)
    }

    private var occurrencesByDay: [Date: [CareOccurrence]] {
        CareSchedule.occurrencesByDay(for: plants, in: monthInterval, calendar: calendar)
    }

    /// Roomier day cells on iPad, where the grid is both wider and further from the eye.
    private var dayCellHeight: CGFloat {
        sizeClass.usesPadLayout ? 60 : 46
    }

    var body: some View {
        WidthReader { width in
            // The month grid needs a fixed slice of the width to stay legible, so the
            // split only happens when what is left over is still worth reading.
            let isSplit = sizeClass.usesPadLayout && width >= Metrics.padTwoColumnWidth

            ScrollView {
                Group {
                    if isSplit {
                        HStack(alignment: .top, spacing: Metrics.padColumnSpacing) {
                            monthCard
                                .frame(width: 420)

                            dayDetail
                                .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    } else {
                        VStack(spacing: Metrics.spacing(for: sizeClass)) {
                            monthCard
                            dayDetail
                        }
                    }
                }
                .padding(Metrics.padding(for: sizeClass))
                .maxContentWidth(Metrics.padContentWidth, enabled: sizeClass.usesPadLayout)
            }
            .background(Color.canvas.ignoresSafeArea())
        }
        .navigationTitle("Calendar")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Today") { goToToday() }
                    .disabled(calendar.isDateInToday(selectedDay) && isViewingCurrentMonth)
            }
        }
    }

    // MARK: - Month

    private var monthCard: some View {
        VStack(spacing: 12) {
            monthHeader
            weekdayHeader
            monthGrid
        }
        .card(padding: sizeClass.usesPadLayout ? 16 : 12)
    }

    private var monthHeader: some View {
        HStack {
            Button { step(by: -1) } label: {
                Image(systemName: "chevron.left")
            }
            .accessibilityLabel("Previous month")

            Spacer()

            Text(visibleMonth, format: .dateTime.month(.wide).year())
                .font(.headline)
                .foregroundStyle(.textPrimary)
                .contentTransition(.numericText())

            Spacer()

            Button { step(by: 1) } label: {
                Image(systemName: "chevron.right")
            }
            .accessibilityLabel("Next month")
        }
        .foregroundStyle(Color.leafGreen)
        .padding(.horizontal, 4)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 2) {
            ForEach(weekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var monthGrid: some View {
        let occurrences = occurrencesByDay

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7), spacing: 4) {
            ForEach(0..<leadingBlankDays, id: \.self) { index in
                Color.clear
                    .frame(height: dayCellHeight)
                    .id("blank-\(index)")
            }

            ForEach(daysInMonth, id: \.self) { day in
                DayCell(
                    day: day,
                    occurrences: occurrences[day] ?? [],
                    isSelected: calendar.isDate(day, inSameDayAs: selectedDay),
                    isToday: calendar.isDateInToday(day),
                    isRegular: sizeClass.usesPadLayout,
                    height: dayCellHeight
                ) {
                    withAnimation(.snappy) { selectedDay = day }
                }
            }
        }
    }

    // MARK: - Day detail

    private var dayDetail: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(
                title: calendar.isDateInToday(selectedDay)
                    ? "Today"
                    : selectedDay.formatted(.dateTime.weekday(.wide).day().month(.wide))
            )

            let events = occurrencesByDay[selectedDay] ?? []

            if events.isEmpty {
                Text("Nothing scheduled.")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .card()
            } else {
                VStack(spacing: 0) {
                    ForEach(events) { event in
                        HStack(spacing: 12) {
                            Image(systemName: event.kind.symbolName)
                                .font(.caption)
                                .foregroundStyle(event.kind.tint)
                                .frame(width: 22)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.plant.name)
                                    .font(.subheadline)
                                    .foregroundStyle(.textPrimary)
                                Text(event.isCompleted ? event.kind.completedTitle : event.kind.title)
                                    .font(.caption)
                                    .foregroundStyle(.textSecondary)
                            }

                            Spacer()

                            if event.isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(Color.leafGreen)
                                    .accessibilityLabel("Completed")
                            }
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, Metrics.cardPadding)

                        if event.id != events.last?.id {
                            Divider().overlay(Color.hairline)
                        }
                    }
                }
                .card(padding: 0)
            }
        }
    }

    // MARK: - Calendar maths

    private var daysInMonth: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: visibleMonth) else { return [] }
        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: monthInterval.start)
        }
    }

    /// Empty cells before the 1st, honouring the locale's first weekday.
    private var leadingBlankDays: Int {
        let weekday = calendar.component(.weekday, from: monthInterval.start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    private var isViewingCurrentMonth: Bool {
        calendar.isDate(visibleMonth, equalTo: .now, toGranularity: .month)
    }

    private func step(by months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: visibleMonth) else { return }
        withAnimation(.snappy) { visibleMonth = next }
    }

    private func goToToday() {
        withAnimation(.snappy) {
            visibleMonth = calendar.startOfMonth(for: .now)
            selectedDay = calendar.startOfDay(for: .now)
        }
    }
}

// MARK: - Day cell

private struct DayCell: View {
    let day: Date
    let occurrences: [CareOccurrence]
    let isSelected: Bool
    let isToday: Bool
    var isRegular = false
    var height: CGFloat = 46
    let onTap: () -> Void

    private var isPast: Bool { day < Calendar.current.startOfDay(for: .now) }

    private var dotColors: [Color] {
        var seen: [Color] = []
        for kind in CareKind.allCases where occurrences.contains(where: { $0.kind == kind }) {
            seen.append(kind.tint)
        }
        return Array(seen.prefix(3))
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 3) {
                Text(day, format: .dateTime.day())
                    .font(isRegular ? .body : .footnote)
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(numberColor)
                    .frame(width: isRegular ? 40 : 30, height: isRegular ? 40 : 30)
                    .background(background, in: Circle())

                HStack(spacing: 3) {
                    ForEach(Array(dotColors.enumerated()), id: \.offset) { _, color in
                        Circle()
                            .fill(color)
                            .frame(width: isRegular ? 5 : 4, height: isRegular ? 5 : 4)
                    }
                }
                .frame(height: 5)
            }
            .frame(height: height)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerLift(isRegular)
        .accessibilityLabel(day.formatted(.dateTime.day().month(.wide)))
        .accessibilityValue(occurrences.isEmpty ? "No tasks" : Format.tasks(occurrences.count))
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private var numberColor: Color {
        if isSelected { return .white }
        if isToday { return .leafGreen }
        return isPast ? .textSecondary.opacity(0.6) : .textPrimary
    }

    private var background: Color {
        if isSelected { return .leafGreen }
        if isToday { return .leafGreen.opacity(0.14) }
        return .clear
    }
}

// MARK: - Calendar helper

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        dateInterval(of: .month, for: date)?.start ?? startOfDay(for: date)
    }
}

#Preview {
    NavigationStack {
        CareCalendarView()
    }
    .modelContainer(PreviewData.container)
}
