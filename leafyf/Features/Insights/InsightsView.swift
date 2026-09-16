import Charts
import SwiftData
import SwiftUI

/// What the care history adds up to: how much was done, where the plants live, how they are
/// doing and whether care is landing on time.
///
/// The screen is pure layout — every number comes from `CareStats`, so nothing here has to be
/// re-derived to be trusted, and the same figures could be shown anywhere else unchanged.
struct InsightsView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Plant.name) private var plants: [Plant]

    private var weekly: [CareStats.WeeklyCare] { CareStats.weeklyActivity(for: plants) }
    private var rooms: [CareStats.RoomCount] { CareStats.plantsByRoom(plants) }
    private var moods: [CareStats.MoodCount] { CareStats.moodBreakdown(plants) }
    private var totals: CareStats.Totals { CareStats.totals(for: plants) }
    private var streak: Int { CareStats.careStreak(for: plants) }

    var body: some View {
        ScrollView {
            Group {
                if plants.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .padding(Metrics.padding(for: sizeClass))
            .maxContentWidth(Metrics.padContentWidth, enabled: sizeClass.usesPadLayout)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Insights")
    }

    // MARK: - Layout

    private var content: some View {
        VStack(spacing: Metrics.spacing(for: sizeClass)) {
            streakHeader
            totalsRow

            if sizeClass.usesPadLayout {
                // Two columns: the charts are wide enough to read side by side, and the
                // screen stops being one long scroll on a 13" display.
                LazyVGrid(
                    columns: PadGrid.columns(minimum: 360, spacing: Metrics.padColumnSpacing),
                    spacing: Metrics.padColumnSpacing
                ) {
                    chartCards
                }
            } else {
                VStack(spacing: Metrics.sectionSpacing) {
                    chartCards
                }
            }
        }
    }

    @ViewBuilder
    private var chartCards: some View {
        WeeklyActivityCard(weekly: weekly)
        RoomsCard(rooms: rooms)
        MoodCard(moods: moods, total: plants.count)
    }

    // MARK: - Header

    private var streakHeader: some View {
        GradientHeader(
            title: streak > 0 ? "\(Format.days(streak)) in a row" : "No streak yet",
            subtitle: streak > 0
                ? "Care has been logged every day for \(Format.days(streak)). Keep it going."
                : "Log a task today and your streak starts.",
            tint: streak > 0 ? .leafGreen : .leafMint
        ) {
            CareRing(
                progress: min(Double(streak) / 14, 1),
                tint: streak > 0 ? .leafGreen : .leafMint,
                size: 62,
                lineWidth: 7,
                caption: "\(streak)"
            )
        }
    }

    private var totalsRow: some View {
        let stats = totals

        return HStack(spacing: 12) {
            StatTile(
                title: "Plants",
                value: "\(stats.plants)",
                symbolName: "leaf.fill",
                tint: .leafGreen
            )

            StatTile(
                title: "This month",
                value: "\(stats.tasksThisMonth)",
                symbolName: "checkmark.circle.fill",
                tint: .leafWater,
                caption: "tasks done"
            )

            StatTile(
                title: "On time",
                value: stats.onTimeRate.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—",
                symbolName: "clock.badge.checkmark.fill",
                tint: .leafGold,
                caption: stats.loggedTasks > 0 ? "of \(Format.tasks(stats.loggedTasks))" : nil
            )
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to chart yet", systemImage: "chart.bar.xaxis")
        } description: {
            Text("Add a plant and log some care. Once there is history, this is where the patterns show up.")
        }
        .padding(.top, 60)
    }
}

// MARK: - Weekly activity

private struct WeeklyActivityCard: View {
    let weekly: [CareStats.WeeklyCare]

    private var hasData: Bool { weekly.contains { $0.count > 0 } }

    var body: some View {
        InsightCard(title: "Care activity", subtitle: "Tasks logged over the last 8 weeks") {
            if hasData {
                Chart(weekly) { bucket in
                    BarMark(
                        x: .value("Week", bucket.weekStart, unit: .weekOfYear),
                        y: .value("Tasks", bucket.count),
                        width: .fixed(18)
                    )
                    .foregroundStyle(by: .value("Care", bucket.kind.title))
                    .cornerRadius(3)
                }
                .chartForegroundStyleScale(
                    domain: CareKind.allCases.map(\.title),
                    range: CareKind.allCases.map(\.tint)
                )
                .chartLegend(position: .bottom, spacing: 12)
                .chartXAxis {
                    // Every other week: eight dated labels will not fit across a phone card.
                    AxisMarks(values: .stride(by: .weekOfYear, count: 2)) { _ in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                            .font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel().font(.caption2)
                    }
                }
                .frame(height: 210)
            } else {
                InlineEmpty(
                    symbolName: "calendar.badge.clock",
                    message: "No care logged in the last eight weeks."
                )
            }
        }
    }
}

// MARK: - Rooms

private struct RoomsCard: View {
    let rooms: [CareStats.RoomCount]

    /// Horizontal bars keep room names readable — vertical ones would have to be rotated.
    private var height: CGFloat {
        CGFloat(max(rooms.count, 1)) * 34 + 24
    }

    var body: some View {
        InsightCard(title: "Where they live", subtitle: "Plants per room") {
            if rooms.isEmpty {
                InlineEmpty(symbolName: "house", message: "No rooms yet.")
            } else {
                Chart(rooms) { room in
                    BarMark(
                        x: .value("Plants", room.count),
                        y: .value("Room", room.room),
                        height: .fixed(18)
                    )
                    .foregroundStyle(Color.leafGreen.gradient)
                    .cornerRadius(4)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(room.count)")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.textSecondary)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine().foregroundStyle(Color.hairline)
                        AxisValueLabel().font(.caption2)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel().font(.caption2)
                    }
                }
                .frame(height: height)
            }
        }
    }
}

// MARK: - Moods

private struct MoodCard: View {
    let moods: [CareStats.MoodCount]
    let total: Int

    var body: some View {
        InsightCard(title: "How they are doing", subtitle: "Right now, across the collection") {
            if moods.isEmpty {
                InlineEmpty(symbolName: "face.smiling", message: "Nothing to summarise yet.")
            } else {
                HStack(spacing: 18) {
                    donut
                    legend
                }
            }
        }
    }

    private var donut: some View {
        Chart(moods) { slice in
            SectorMark(
                angle: .value("Plants", slice.count),
                innerRadius: .ratio(0.62),
                angularInset: 1.5
            )
            .cornerRadius(4)
            .foregroundStyle(by: .value("Mood", slice.mood.title))
        }
        .chartForegroundStyleScale(
            domain: moods.map(\.mood.title),
            range: moods.map(\.mood.tint)
        )
        .chartLegend(.hidden)
        .frame(width: 140, height: 140)
        .overlay {
            VStack(spacing: 0) {
                Text("\(total)")
                    .font(.title3.bold())
                    .foregroundStyle(.textPrimary)
                    .monospacedDigit()
                Text(total == 1 ? "plant" : "plants")
                    .font(.caption2)
                    .foregroundStyle(.textSecondary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Mood breakdown")
        .accessibilityValue(moods.map { "\($0.count) \($0.mood.title)" }.joined(separator: ", "))
    }

    private var legend: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(moods) { slice in
                HStack(spacing: 8) {
                    Circle()
                        .fill(slice.mood.tint)
                        .frame(width: 9, height: 9)

                    Text(slice.mood.title)
                        .font(.caption)
                        .foregroundStyle(.textPrimary)

                    Spacer(minLength: 6)

                    Text("\(slice.count)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.textSecondary)
                        .monospacedDigit()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

// MARK: - Card chrome

/// One chart plus its heading, so every card on the screen has the same shape.
private struct InsightCard<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: title, subtitle: subtitle)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

private struct InlineEmpty: View {
    let symbolName: String
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(Color.leafMint)
            Text(message)
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

#Preview {
    NavigationStack {
        InsightsView()
    }
    .modelContainer(PreviewData.container)
}
