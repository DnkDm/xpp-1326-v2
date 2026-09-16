import SwiftUI
import UIKit

/// iPad: a portrait card that leads with the photo.
///
/// The row layout squeezes the name against the mood badge once a grid column gets
/// narrower than the full screen, and a plant app has photos worth showing anyway.
struct PlantCard: View {
    let plant: Plant

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            cover

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

                HStack(alignment: .bottom) {
                    Text(plant.statusText(for: .watering))
                        .font(.subheadline)
                        .foregroundStyle(plant.urgencyTint(for: .watering))

                    Spacer(minLength: 8)

                    CareRings(plant: plant, size: 32)
                }
                .padding(.top, 2)
            }
            .padding(Metrics.cardPadding)
        }
        .background(Color.surface, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plant.name), \(plant.mood.title)")
        .accessibilityHint(plant.statusText(for: .watering))
    }

    private var cover: some View {
        Group {
            if let data = plant.thumbnailData ?? plant.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.leafGreen.opacity(0.12)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.leafGreen)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        .clipped()
        .accessibilityHidden(true)
    }
}

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

                HStack(alignment: .bottom) {
                    Text(plant.statusText(for: .watering))
                        .font(.subheadline)
                        .foregroundStyle(plant.urgencyTint(for: .watering))

                    Spacer(minLength: 8)

                    CareRings(plant: plant, size: 28)
                }
            }
        }
        .card()
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(plant.name), \(plant.mood.title)")
        .accessibilityHint(plant.statusText(for: .watering))
    }
}

// MARK: - Care rings

/// All three schedules at a glance: each ring fills as its task comes due and takes on that
/// task's `urgencyTint`, so a row says what needs doing without spelling it out three times.
private struct CareRings: View {
    let plant: Plant
    var size: CGFloat = 30

    var body: some View {
        HStack(spacing: 8) {
            ForEach(CareKind.allCases) { kind in
                CareRing(
                    progress: plant.progress(for: kind),
                    tint: plant.urgencyTint(for: kind),
                    size: size,
                    lineWidth: 3.5,
                    symbolName: kind.symbolName
                )
            }
        }
        .accessibilityHidden(true)
    }
}
