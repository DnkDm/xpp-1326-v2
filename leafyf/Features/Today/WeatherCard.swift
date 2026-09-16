import SwiftData
import SwiftUI

// MARK: - Card

/// Today's weather for the saved place, translated into care advice for the plants the
/// user actually owns.
///
/// The card owns its own loading: Today should not have to know that weather exists
/// beyond giving this view a place to sit and a pull-to-refresh gesture.
struct WeatherCard: View {
    var store: WeatherStore = .shared

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \Plant.name) private var plants: [Plant]
    @State private var isShowingPlacePicker = false

    private var tips: [CareTip] {
        guard let snapshot = store.snapshot else { return [] }
        return CareAdvisor.advice(for: snapshot, plants: plants)
    }

    var body: some View {
        content
            .sheet(isPresented: $isShowingPlacePicker) {
                PlacePickerView(store: store)
            }
            .task { await store.refresh() }
            // Today is usually left open: coming back to it hours later should not show
            // yesterday evening's forecast until something else happens to touch the view.
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await store.refresh() }
            }
    }

    @ViewBuilder
    private var content: some View {
        if store.place == nil {
            WeatherPrompt { isShowingPlacePicker = true }
        } else if let snapshot = store.snapshot {
            loaded(snapshot)
        } else if store.isLoadingWithoutData {
            // The real layout, blanked out: the card keeps its height and the content
            // does not jump when the first forecast lands.
            loaded(.preview)
                .redacted(reason: .placeholder)
                .accessibilityLabel("Loading weather")
        } else {
            WeatherFailureCard(error: store.error) {
                Task { await store.refresh(force: true) }
            }
        }
    }

    // MARK: - Loaded

    private func loaded(_ snapshot: WeatherSnapshot) -> some View {
        VStack(spacing: 0) {
            WeatherHero(snapshot: snapshot, isPad: sizeClass.usesPadLayout) {
                Task { await store.refresh(force: true) }
            }

            if !tips.isEmpty {
                CareTipList(tips: tips, isPad: sizeClass.usesPadLayout)
            }

            // Old data with no warning reads as current data. The footer is the only thing
            // separating "27° right now" from "27° at some point this morning".
            if store.error != nil || snapshot.isStale {
                StaleFooter(snapshot: snapshot, error: store.error)
            }
        }
        .background(Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
        .onTapGesture { isShowingPlacePicker = true }
        .accessibilityAction(named: "Change location") { isShowingPlacePicker = true }
    }
}

// MARK: - Hero

/// The coloured half of the card: condition, temperature and the numbers that drive the
/// advice below it.
private struct WeatherHero: View {
    let snapshot: WeatherSnapshot
    let isPad: Bool
    let onRefresh: () -> Void

    private var condition: WeatherCondition { snapshot.condition }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            placeRow
            temperatureRow
            metricsRow
            sunRow
        }
        .padding(isPad ? 20 : Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: condition.gradientColors(isDaytime: snapshot.isDaytime),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .foregroundStyle(.white)
    }

    private var placeRow: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.caption2)

            Text(snapshot.placeName)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 8)

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .font(.caption.weight(.semibold))
                    .padding(7)
                    .background(.white.opacity(0.18), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Refresh weather")
        }
        .foregroundStyle(.white.opacity(0.92))
    }

    private var temperatureRow: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(snapshot.temperatureText)
                    .font(.system(size: isPad ? 52 : 44, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())

                Text(condition.label)
                    .font(.headline)

                Text(snapshot.highLowText)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer(minLength: 0)

            Image(systemName: condition.symbolName(isDaytime: snapshot.isDaytime))
                .font(.system(size: isPad ? 66 : 56))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                .symbolEffect(.pulse, options: .repeating, isActive: condition.isSunny)
                .symbolEffect(.variableColor.iterative.reversing, options: .repeating, isActive: condition.isWet)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    private var metricsRow: some View {
        HStack(spacing: 8) {
            WeatherMetric(symbolName: "humidity.fill", value: snapshot.humidityText, label: "Humidity")
            WeatherMetric(symbolName: "sun.max.fill", value: snapshot.daylightText, label: "Daylight")
            WeatherMetric(symbolName: "sun.dust.fill", value: "UV \(snapshot.uvText)", label: "UV index")
        }
    }

    private var sunRow: some View {
        HStack(spacing: 14) {
            Label(snapshot.sunriseText, systemImage: "sunrise.fill")
                .accessibilityLabel("Sunrise at \(snapshot.sunriseText)")

            Rectangle()
                .fill(.white.opacity(0.3))
                .frame(height: 1)
                .accessibilityHidden(true)

            Label(snapshot.sunsetText, systemImage: "sunset.fill")
                .accessibilityLabel("Sunset at \(snapshot.sunsetText)")
        }
        .font(.caption.weight(.medium))
        .foregroundStyle(.white.opacity(0.92))
        .labelStyle(.titleAndIcon)
    }
}

/// One frosted pill inside the hero — humidity, daylight or UV.
private struct WeatherMetric: View {
    let symbolName: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: symbolName)
                .font(.caption2)
            Text(value)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.18), in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(label) \(value)")
    }
}

// MARK: - Tips

private struct CareTipList: View {
    let tips: [CareTip]
    let isPad: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "What this means for your plants")

            if isPad {
                // Side by side once there is room, so the card stays a band rather than
                // a tall column on a 13" screen.
                LazyVGrid(columns: PadGrid.columns(minimum: 260, spacing: 12), alignment: .leading, spacing: 12) {
                    ForEach(tips) { CareTipRow(tip: $0) }
                }
            } else {
                ForEach(tips) { CareTipRow(tip: $0) }
            }
        }
        .padding(Metrics.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct CareTipRow: View {
    let tip: CareTip

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tip.symbolName)
                .font(.footnote)
                .foregroundStyle(tip.tint)
                .frame(width: 28, height: 28)
                .background(tip.tint.opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tip.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)

                Text(tip.detail)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Other states

/// Shown until a place is saved. It sells the feature rather than apologising for missing data.
private struct WeatherPrompt: View {
    let onPick: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cloud.sun.fill")
                .font(.title)
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.leafGold, Color.leafWater)

            VStack(alignment: .leading, spacing: 8) {
                Text("Care that follows the weather")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)

                Text("Set your location and Leafy will tell you when a hot, dry or dark day changes what your plants need.")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onPick) {
                    Label("Set your location", systemImage: "location.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(Color.leafGreen, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// A place is set but there is nothing cached to fall back on.
private struct WeatherFailureCard: View {
    let error: WeatherError?
    let onRetry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "cloud.slash.fill")
                .font(.title3)
                .foregroundStyle(.textSecondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("Weather unavailable")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)

                Text(error?.errorDescription ?? "Leafy could not reach the forecast.")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Try again", action: onRetry)
                    .font(.caption.weight(.semibold))
                    .padding(.top, 2)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

/// Thin honesty bar under a cached card: the data is real, just not from a minute ago.
private struct StaleFooter: View {
    let snapshot: WeatherSnapshot
    let error: WeatherError?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.caption2)

            Text("\(error?.shortDescription ?? "Not refreshed") · Updated \(snapshot.ageText)")
                .font(.caption2)

            Spacer(minLength: 0)
        }
        .foregroundStyle(.textSecondary)
        .padding(.horizontal, Metrics.cardPadding)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surfaceMuted)
    }
}

// MARK: - Previews

#Preview("Loaded") {
    ScrollView {
        WeatherCard(store: .previewStore())
            .padding()
    }
    .background(Color.canvas)
    .modelContainer(PreviewData.container)
}

#Preview("States") {
    ScrollView {
        VStack(spacing: 16) {
            WeatherCard(store: .previewStore(snapshot: nil, place: nil))
            WeatherCard(store: .previewStore(snapshot: nil, isLoading: true))
            WeatherCard(store: .previewStore(snapshot: nil, error: .offline))
            WeatherCard(store: .previewStore(error: .offline))
        }
        .padding()
    }
    .background(Color.canvas)
    .modelContainer(PreviewData.container)
}

#Preview("Rainy night") {
    var snapshot = WeatherSnapshot.preview
    snapshot.condition = .rain
    snapshot.isDaytime = false
    snapshot.temperatureC = 8
    snapshot.lowC = 3
    snapshot.humidity = 88
    snapshot.precipitationMM = 6

    return ScrollView {
        WeatherCard(store: .previewStore(snapshot: snapshot))
            .padding()
    }
    .background(Color.canvas)
    .modelContainer(PreviewData.container)
    .preferredColorScheme(.dark)
}
