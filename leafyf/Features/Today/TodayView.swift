import SwiftData
import SwiftUI

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Plant.name) private var plants: [Plant]

    /// Tasks the user chose to ignore for now. Cleared on the next launch, by design.
    @State private var skippedTaskIDs: Set<String> = []

    private var dueTasks: [CareTask] {
        CareSchedule.dueTasks(for: plants).filter { !skippedTaskIDs.contains($0.id) }
    }

    private var completedToday: [CareLogEntry] {
        CareSchedule.log(for: plants)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Metrics.sectionSpacing) {
                    header

                    if dueTasks.isEmpty && completedToday.isEmpty {
                        emptyState
                    } else {
                        if !dueTasks.isEmpty {
                            taskSection
                        }
                        if !completedToday.isEmpty {
                            completedSection
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Today")
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline)
                .foregroundStyle(.textSecondary)

            Text(headline)
                .font(.title2.bold())
                .foregroundStyle(.textPrimary)
        }
    }

    private var headline: String {
        if plants.isEmpty { return "Add your first plant" }
        if dueTasks.isEmpty { return "Everything is taken care of" }
        return "\(Format.tasks(dueTasks.count)) to go"
    }

    private var taskSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Due now")

            ForEach(dueTasks) { task in
                CareTaskRow(
                    task: task,
                    onComplete: { complete(task) },
                    onSkip: { skip(task) }
                )
            }
        }
    }

    private var completedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Done today")

            VStack(spacing: 0) {
                ForEach(completedToday) { entry in
                    CompletedCareRow(entry: entry)

                    if entry.id != completedToday.last?.id {
                        Divider().overlay(Color.hairline)
                    }
                }
            }
            .card(padding: 0)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(
                plants.isEmpty ? "No plants yet" : "Nothing due today",
                systemImage: plants.isEmpty ? "leaf" : "checkmark.circle"
            )
        } description: {
            Text(
                plants.isEmpty
                    ? "Add a plant on the Plants tab and Leafy will build its schedule."
                    : "Your plants are happy. Check back tomorrow."
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: - Actions

    private func complete(_ task: CareTask) {
        withAnimation(.snappy) {
            PlantCare.log(task.kind, for: task.plant, in: context)
            skippedTaskIDs.remove(task.id)
        }
    }

    private func skip(_ task: CareTask) {
        _ = withAnimation(.snappy) { skippedTaskIDs.insert(task.id) }
    }
}

// MARK: - Rows

private struct CareTaskRow: View {
    let task: CareTask
    let onComplete: () -> Void
    let onSkip: () -> Void

    private var isOverdue: Bool { task.isOverdue() }

    var body: some View {
        HStack(spacing: 12) {
            PlantThumbnail(plant: task.plant, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: task.kind.symbolName)
                        .font(.caption)
                        .foregroundStyle(task.kind.tint)
                    Text(task.kind.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.textPrimary)
                }

                Text(task.plant.name)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)

                if isOverdue {
                    Text(task.plant.statusText(for: task.kind))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.leafClay)
                }
            }

            Spacer(minLength: 8)

            HStack(spacing: 8) {
                Button("Skip", action: onSkip)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.canvas, in: Capsule())

                Button(task.kind.actionTitle, action: onComplete)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(task.kind.tint, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .card()
    }
}

private struct CompletedCareRow: View {
    let entry: CareLogEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.leafGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind.completedTitle)
                    .font(.subheadline)
                    .foregroundStyle(.textPrimary)
                if let name = entry.plant?.name {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }

            Spacer()

            Text(entry.date, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .padding(Metrics.cardPadding)
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
}
