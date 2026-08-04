import SwiftUI

/// Browsable care presets. Presented as a picker from the plant form, or read-only from Settings.
struct PlantLibraryView: View {
    var onSelect: ((PlantSpecies) -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var results: [PlantSpecies] {
        guard !searchText.isEmpty else { return PlantSpecies.catalog }
        return PlantSpecies.catalog.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
                || $0.summary.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    disclaimer

                    ForEach(results) { species in
                        SpeciesCard(species: species, isSelectable: onSelect != nil) {
                            onSelect?(species)
                        }
                    }

                    if results.isEmpty {
                        ContentUnavailableView.search(text: searchText)
                            .padding(.top, 40)
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Plant library")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search species")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(onSelect == nil ? "Done" : "Cancel") { dismiss() }
                }
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
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                Text(species.emoji)
                    .font(.system(size: 34))
                    .frame(width: 58, height: 58)
                    .background(Color.canvas, in: RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))

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
            .card()
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable)
    }
}

#Preview {
    PlantLibraryView { _ in }
}
