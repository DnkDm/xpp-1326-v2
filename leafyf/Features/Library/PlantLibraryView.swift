import SwiftUI

/// Browsable care presets. Presented as a picker from the plant form, or read-only from Settings.
struct PlantLibraryView: View {
    var onSelect: ((PlantSpecies) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var searchText = ""

    private var results: [PlantSpecies] {
        guard !searchText.isEmpty else { return PlantSpecies.catalog }
        return PlantSpecies.catalog.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.scientificName.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 12) {
                    disclaimer

                    if results.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    } else if sizeClass.usesPadLayout {
                        LazyVGrid(columns: PadGrid.columns(minimum: 380), spacing: 16) {
                            speciesCards
                        }
                    } else {
                        LazyVStack(spacing: 12) {
                            speciesCards
                        }
                    }
                }
                .padding(Metrics.padding(for: sizeClass))
                .maxContentWidth(Metrics.padContentWidth, enabled: sizeClass.usesPadLayout)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Plant library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search species")
            // "Learn more" pushes the Wikipedia article inside the picker, so reading up
            // on a species never costs the user the form they were filling in.
            .navigationDestination(for: ArticleRequest.self) { request in
                SpeciesArticleView(request: request, onUseSpecies: onSelect)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(onSelect == nil ? "Done" : "Cancel") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var speciesCards: some View {
        ForEach(results) { species in
            SpeciesCard(
                species: species,
                isSelectable: onSelect != nil,
                showsPointerEffect: sizeClass.usesPadLayout
            ) {
                onSelect?(species)
            }
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .foregroundStyle(Color.leafGold)

            Text("General guidance to start from — adjust once you know how your plant behaves.")
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(background: .surfaceMuted)
    }
}

private struct SpeciesCard: View {
    let species: PlantSpecies
    let isSelectable: Bool
    var showsPointerEffect = false
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button(action: onTap) {
                details
            }
            .buttonStyle(.plain)
            .pointerLift(showsPointerEffect && isSelectable)
            .disabled(!isSelectable)

            Divider().overlay(Color.hairline)

            learnMoreLink
        }
        .card()
    }

    private var details: some View {
        HStack(spacing: 14) {
            Image(species.artworkName)
                .resizable()
                .scaledToFill()
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 5) {
                Text(species.name)
                    .font(.headline)
                    .foregroundStyle(.textPrimary)

                Text(species.summary)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Label("every \(Format.days(species.wateringIntervalDays))", systemImage: "drop.fill")
                        .foregroundStyle(Color.leafWater)
                    Label(species.light, systemImage: "sun.max.fill")
                        .foregroundStyle(Color.leafGold)
                }
                .font(.caption2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isSelectable {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.leafGreen)
            }
        }
        .contentShape(Rectangle())
    }

    /// Kept as its own control below the card body rather than an icon inside it: nested
    /// tappable areas inside a button label swallow each other's taps.
    private var learnMoreLink: some View {
        NavigationLink(value: ArticleRequest(species: species)) {
            HStack(spacing: 6) {
                Image(systemName: "book.pages")
                Text("Learn more")
                Text("·")
                Text(species.scientificName)
                    .italic()
                    .lineLimit(1)

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.caption2)
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(Color.leafGreen)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerLift(showsPointerEffect)
    }
}

#Preview {
    PlantLibraryView { _ in }
}
