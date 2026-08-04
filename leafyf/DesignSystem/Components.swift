import SwiftUI
import UIKit

// MARK: - Chip

struct Chip: View {
    let title: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.white : .textPrimary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.leafGreen : Color.surface, in: Capsule())
                .overlay(Capsule().strokeBorder(Color.hairline, lineWidth: isSelected ? 0 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

// MARK: - Mood badge

struct MoodBadge: View {
    let mood: PlantMood

    var body: some View {
        HStack(spacing: 4) {
            Text(mood.emoji)
            Text(mood.title)
                .fontWeight(.medium)
        }
        .font(.caption2)
        .foregroundStyle(mood.tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(mood.tint.opacity(0.14), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mood.title)
    }
}

// MARK: - Plant thumbnail

struct PlantThumbnail: View {
    let plant: Plant
    var size: CGFloat = 64

    var body: some View {
        Group {
            if let data = plant.thumbnailData ?? plant.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Color.leafGreen.opacity(0.12)
                    Image(systemName: "leaf.fill")
                        .font(.system(size: size * 0.36))
                        .foregroundStyle(Color.leafGreen)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Progress bar

struct CareProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(tint.opacity(0.15))
                Capsule()
                    .fill(tint)
                    .frame(width: max(proxy.size.width * progress, progress > 0 ? 4 : 0))
            }
        }
        .frame(height: 5)
        .accessibilityHidden(true)
    }
}

// MARK: - Buttons

struct PrimaryButtonStyle: ButtonStyle {
    var tint: Color = .leafGreen

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(tint, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            .opacity(configuration.isPressed ? 0.85 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textPrimary)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Photo picker tile

struct PhotoPickerTile: View {
    let photo: ProcessedPhoto?
    let existingData: Data?
    var height: CGFloat = 180
    var prompt: String = "Add a photo"

    var body: some View {
        ZStack {
            if let image = displayImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.canvas
                VStack(spacing: 8) {
                    Image(systemName: "photo.badge.plus")
                        .font(.title2)
                    Text(prompt)
                        .font(.subheadline)
                }
                .foregroundStyle(Color.leafGreen)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .strokeBorder(Color.hairline, lineWidth: 1)
        )
    }

    private var displayImage: UIImage? {
        if let photo { return UIImage(data: photo.full) }
        if let existingData { return UIImage(data: existingData) }
        return nil
    }
}

// MARK: - Formatting

enum Format {
    static func days(_ count: Int) -> String {
        "\(count) \(count == 1 ? "day" : "days")"
    }

    static func plants(_ count: Int) -> String {
        "\(count) \(count == 1 ? "plant" : "plants")"
    }

    static func tasks(_ count: Int) -> String {
        "\(count) \(count == 1 ? "task" : "tasks")"
    }
}
