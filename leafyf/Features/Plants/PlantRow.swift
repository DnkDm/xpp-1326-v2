import SwiftUI

struct PlantRow: View {
    let plant: Plant

    var body: some View {
        HStack(spacing: 14) {
            PlantThumbnail(plant: plant, size: 68)

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(plant.name)
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    MoodBadge(mood: plant.mood)
                }

                Text(plant.displaySpecies)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)

                Text(plant.statusText(for: .watering))
                    .font(.subheadline)
                    .foregroundStyle(statusColor)

                CareProgressBar(
                    progress: plant.progress(for: .watering),
                    tint: statusColor
                )
            }
        }
        .card()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plant.name), \(plant.mood.title)")
        .accessibilityHint(plant.statusText(for: .watering))
    }

    private var statusColor: Color {
        switch plant.mood {
        case .overdue: .leafClay
        case .dueToday: .leafGold
        case .settlingIn, .thriving: .leafGreen
        }
    }
}
