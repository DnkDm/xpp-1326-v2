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
                // No photo yet: the species illustration stands in, so a fresh plant still
                // looks like itself in every list.
                Image(plant.artworkName)
                    .resizable()
                    .scaledToFill()
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

/// Press feedback for a whole card or row that acts as a button.
///
/// `.plain` leaves a tapped card completely inert, which on a screen made of cards reads as a
/// missed tap. This dips it just enough to acknowledge the touch without bouncing the layout.
struct CardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.snappy(duration: 0.18), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == CardButtonStyle {
    static var card: CardButtonStyle { CardButtonStyle() }
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

// MARK: - Care ring

/// A circular take on `CareProgressBar`, for the places where a row of three tiny dials
/// says more at a glance than three stacked bars: how far through its interval one task is.
///
/// The ring fills from empty when it appears, which turns a static list into something that
/// feels alive the moment a screen is pushed.
struct CareRing: View {
    let progress: Double
    let tint: Color
    var size: CGFloat = 34
    var lineWidth: CGFloat = 4
    var symbolName: String?
    /// Shown inside the ring instead of a symbol — used for the big rings on plant detail.
    var caption: String?

    @State private var shownProgress: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.16), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(shownProgress, 0.001))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            if let caption {
                Text(caption)
                    .font(.system(size: size * 0.26, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .monospacedDigit()
                    .minimumScaleFactor(0.6)
                    .padding(size * 0.18)
            } else if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.34))
                    .foregroundStyle(tint)
            }
        }
        .frame(width: size, height: size)
        .animation(.snappy(duration: 0.55), value: shownProgress)
        .onAppear { shownProgress = clamped(progress) }
        .onChange(of: progress) { _, new in shownProgress = clamped(new) }
        .accessibilityHidden(true)
    }

    private func clamped(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

// MARK: - Stat tile

/// One number with a label, sized to sit in a row of its siblings.
struct StatTile: View {
    let title: String
    let value: String
    var symbolName: String
    var tint: Color = .leafGreen
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: symbolName)
                .font(.subheadline)
                .foregroundStyle(tint)

            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(title)
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .lineLimit(2)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(tint)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

// MARK: - Empty state card

/// The in-card cousin of `ContentUnavailableView`, for empty sections that sit inside a
/// screen that is otherwise full — a chart with no data, a history with no entries.
struct EmptyStateCard: View {
    let symbolName: String
    let title: String
    var message: String?
    var tint: Color = .leafGreen
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.title2)
                .foregroundStyle(tint)
                .padding(14)
                .background(tint.opacity(0.12), in: Circle())

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textPrimary)

            if let message {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(tint)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .card()
    }
}

// MARK: - Gradient header

/// A soft tinted banner for the top of a screen, so a wall of cards starts with something
/// with colour in it rather than a title floating over the canvas.
struct GradientHeader<Trailing: View>: View {
    let title: String
    var subtitle: String?
    var symbolName: String?
    var tint: Color = .leafGreen
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            trailing()

            if let symbolName {
                Image(systemName: symbolName)
                    .font(.system(size: 34))
                    .foregroundStyle(tint.opacity(0.9))
            }
        }
        .padding(Metrics.cardPadding)
        .background(
            LinearGradient(
                colors: [tint.opacity(0.22), tint.opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                .strokeBorder(tint.opacity(0.18), lineWidth: 1)
        )
    }
}

extension GradientHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, symbolName: String? = nil, tint: Color = .leafGreen) {
        self.init(title: title, subtitle: subtitle, symbolName: symbolName, tint: tint) { EmptyView() }
    }
}

// MARK: - Haptics

/// Feedback for the moments the user changed something in the world — logging care,
/// finishing an import. Deliberately sparse: everything else is silent.
@MainActor
enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light) {
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
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

#Preview("Components") {
    ScrollView {
        VStack(spacing: Metrics.sectionSpacing) {
            GradientHeader(
                title: "7 days in a row",
                subtitle: "Care logged every day this week.",
                symbolName: "flame.fill"
            )

            HStack(spacing: 12) {
                StatTile(title: "Plants", value: "6", symbolName: "leaf.fill")
                StatTile(title: "Tasks this month", value: "18", symbolName: "checkmark.circle.fill", tint: .leafWater)
                StatTile(title: "On time", value: "82%", symbolName: "clock.badge.checkmark.fill", tint: .leafGold, caption: "of 44 tasks")
            }

            HStack(spacing: 14) {
                ForEach(CareKind.allCases) { kind in
                    CareRing(progress: 0.72, tint: kind.tint, size: 54, lineWidth: 6, symbolName: kind.symbolName)
                }
            }
            .frame(maxWidth: .infinity)
            .card()

            EmptyStateCard(
                symbolName: "chart.bar.xaxis",
                title: "No care logged yet",
                message: "Log a task and the chart fills in.",
                actionTitle: "Log watering",
                action: {}
            )
        }
        .padding(Metrics.screenPadding)
    }
    .background(Color.canvas.ignoresSafeArea())
}
