import SwiftData
import SwiftUI

/// Wikipedia, framed for plant people: search anything, or browse the species Leafy
/// already knows and a shelf of care guides.
///
/// No `NavigationStack` of its own — the root supplies one per section, and nesting a
/// second would break the iPad sidebar's single detail column.
struct ExploreView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var query = ""
    @State private var results: LoadState<[WikipediaSearchResult]> = .idle
    /// Bumped by the retry button. Part of the `.task(id:)` key, so retrying re-runs the
    /// same search without the user having to change a character.
    @State private var retryToken = 0

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Any change here cancels the in-flight request, which is what makes the debounce
    /// below both a debounce and a stale-response guard.
    private var searchKey: String { "\(retryToken)\u{1}\(query)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacing(for: sizeClass)) {
                if isSearching {
                    searchResults
                } else {
                    intro
                    popularSection
                    guidesSection
                }
            }
            .padding(Metrics.padding(for: sizeClass))
            .maxContentWidth(Metrics.padContentWidth, enabled: sizeClass.usesPadLayout)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Explore")
        .searchable(text: $query, prompt: "Search plants and care topics")
        .autocorrectionDisabled()
        .navigationDestination(for: ArticleRequest.self) { request in
            SpeciesArticleView(request: request)
        }
        .task(id: searchKey) { await runSearch() }
    }

    // MARK: - Discover

    private var intro: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "book.pages")
                .foregroundStyle(Color.leafGreen)

            Text("Articles come from Wikipedia. Care intervals are Leafy's own starting points — adjust them once you know your plant.")
                .font(.caption)
                .foregroundStyle(.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(background: .surfaceMuted)
    }

    private var popularSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Popular houseplants", subtitle: "\(PlantSpecies.catalog.count) species Leafy can set up for you")

            LazyVGrid(columns: PadGrid.columns(minimum: tileWidth, spacing: 12), spacing: 12) {
                ForEach(PlantSpecies.catalog) { species in
                    SpeciesTile(species: species, showsPointerEffect: sizeClass.usesPadLayout)
                }
            }
        }
    }

    /// Two tiles across on a phone, as many as fit on an iPad.
    private var tileWidth: CGFloat {
        sizeClass.usesPadLayout ? 220 : 150
    }

    private var guidesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Care guides", subtitle: "The background behind the reminders")

            VStack(spacing: 0) {
                ForEach(CareGuide.all) { guide in
                    NavigationLink(value: ArticleRequest(wikipediaTitle: guide.wikipediaTitle, displayName: guide.title)) {
                        CareGuideRow(guide: guide)
                    }
                    .buttonStyle(.plain)
                    .pointerLift(sizeClass.usesPadLayout)

                    if guide.id != CareGuide.all.last?.id {
                        Divider().overlay(Color.hairline)
                    }
                }
            }
            .card(padding: 0)
        }
    }

    // MARK: - Search

    @ViewBuilder
    private var searchResults: some View {
        switch results {
        case .idle:
            searchHint
        case .loading:
            ProgressView("Searching Wikipedia…")
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
        case .loaded(let found) where found.isEmpty:
            ContentUnavailableView.search(text: query)
                .padding(.top, 40)
        case .loaded(let found):
            LazyVStack(spacing: 12) {
                ForEach(found) { result in
                    SearchResultCard(result: result, showsPointerEffect: sizeClass.usesPadLayout)
                }
            }
        case .failed(let error):
            errorState(error)
        }
    }

    /// Shown for a single character, where a search would only return noise.
    private var searchHint: some View {
        ContentUnavailableView {
            Label("Keep typing", systemImage: "magnifyingglass")
        } description: {
            Text("Search for a species, a genus, or a care topic like repotting.")
        }
        .padding(.top, 40)
    }

    private func errorState(_ error: APIError) -> some View {
        ContentUnavailableView {
            Label("Search failed", systemImage: error.symbolName)
        } description: {
            Text(error.message)
        } actions: {
            Button("Try again") { retryToken += 1 }
                .buttonStyle(.borderedProminent)
                .tint(.leafGreen)
        }
        .padding(.top, 40)
    }

    // MARK: - Loading

    /// Waits out the typist, searches, then fills in thumbnails in a second pass.
    private func runSearch() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = .idle
            return
        }

        // `.task(id:)` tears this task down on the next keystroke, so a cancelled sleep
        // means the query moved on and there is nothing left to do.
        do {
            try await Task.sleep(for: .milliseconds(350))
        } catch {
            return
        }

        results = .loading

        do {
            let found = try await WikipediaService.search(trimmed)
            try Task.checkCancellation()
            withAnimation(.snappy) { results = .loaded(found) }
            await loadThumbnails(for: found)
        } catch {
            let failure = APIError.wrapping(error)
            guard !failure.isCancellation else { return }
            withAnimation(.snappy) { results = .failed(failure) }
        }
    }

    /// The search endpoint returns no images, so the visible rows get their thumbnails
    /// from one batched follow-up request rather than one request per row.
    private func loadThumbnails(for found: [WikipediaSearchResult]) async {
        let titles = Array(found.prefix(12).map(\.title))
        guard !titles.isEmpty, let images = try? await WikipediaService.thumbnails(for: titles) else { return }

        // The user may have typed on while this was in flight; only decorate the results
        // that are still on screen.
        guard case .loaded(let current) = results, current.map(\.title) == found.map(\.title) else { return }

        withAnimation(.snappy) {
            results = .loaded(current.map { result in
                var decorated = result
                decorated.thumbnailURL = images[result.title]
                return decorated
            })
        }
    }
}

// MARK: - Species tile

private struct SpeciesTile: View {
    let species: PlantSpecies
    var showsPointerEffect = false

    var body: some View {
        NavigationLink(value: ArticleRequest(species: species)) {
            VStack(alignment: .leading, spacing: 8) {
                Image(species.artworkName)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 110)
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))
                    .accessibilityHidden(true)

                Text(species.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2, reservesSpace: true)

                Text(species.scientificName)
                    .font(.caption2.italic())
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)

                Label("every \(Format.days(species.wateringIntervalDays))", systemImage: "drop.fill")
                    .font(.caption2)
                    .foregroundStyle(Color.leafWater)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()
        }
        .buttonStyle(.plain)
        .pointerLift(showsPointerEffect)
    }
}

// MARK: - Search result card

private struct SearchResultCard: View {
    let result: WikipediaSearchResult
    var showsPointerEffect = false

    var body: some View {
        NavigationLink(value: ArticleRequest(searchResult: result)) {
            HStack(spacing: 14) {
                thumbnail

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.headline)
                        .foregroundStyle(.textPrimary)

                    Text(result.snippet)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            .card()
        }
        .buttonStyle(.plain)
        .pointerLift(showsPointerEffect)
    }

    /// Fades in whenever the batched image request catches up; until then the tile keeps
    /// the row's height stable so the list never jumps.
    private var thumbnail: some View {
        AsyncImage(url: result.thumbnailURL, transaction: Transaction(animation: .snappy)) { phase in
            if let image = phase.image {
                image.resizable().scaledToFill()
            } else {
                ZStack {
                    Color.canvas
                    Image(systemName: "leaf")
                        .foregroundStyle(Color.leafGreen.opacity(0.6))
                }
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Care guides

/// Curated Wikipedia articles that explain the "why" behind Leafy's reminders.
private struct CareGuide: Identifiable, Hashable {
    let title: String
    let subtitle: String
    let symbolName: String
    let tint: Color
    /// Exact article title, which is often not what the row is labelled.
    let wikipediaTitle: String

    var id: String { wikipediaTitle }

    static let all: [CareGuide] = [
        CareGuide(
            title: "Houseplant basics",
            subtitle: "What makes a plant an indoor plant",
            symbolName: "house",
            tint: .leafGreen,
            wikipediaTitle: "Houseplant"
        ),
        CareGuide(
            title: "Root rot",
            subtitle: "What overwatering actually does",
            symbolName: "drop.triangle",
            tint: .leafWater,
            wikipediaTitle: "Root rot"
        ),
        CareGuide(
            title: "Repotting",
            subtitle: "Moving a plant without setting it back",
            symbolName: "arrow.up.bin",
            tint: .leafClay,
            wikipediaTitle: "Transplanting"
        ),
        CareGuide(
            title: "Potting soil",
            subtitle: "Why indoor mixes are not garden soil",
            symbolName: "square.stack.3d.down.right",
            tint: .leafClay,
            wikipediaTitle: "Potting soil"
        ),
        CareGuide(
            title: "Propagation",
            subtitle: "Turning one plant into several",
            symbolName: "scissors",
            tint: .leafMint,
            wikipediaTitle: "Plant propagation"
        ),
        CareGuide(
            title: "Fertilizer",
            subtitle: "What the three numbers on the bottle mean",
            symbolName: "leaf",
            tint: .leafGold,
            wikipediaTitle: "Fertilizer"
        ),
        CareGuide(
            title: "Humidity",
            subtitle: "The number tropical plants care about most",
            symbolName: "humidity",
            tint: .leafWater,
            wikipediaTitle: "Humidity"
        ),
        CareGuide(
            title: "Spider mites",
            subtitle: "The pest behind speckled, dusty leaves",
            symbolName: "ant",
            tint: .leafClay,
            wikipediaTitle: "Spider mite"
        ),
        CareGuide(
            title: "Fungus gnats",
            subtitle: "The flies that mean the soil stays too wet",
            symbolName: "aqi.medium",
            tint: .leafGold,
            wikipediaTitle: "Fungus gnat"
        ),
        CareGuide(
            title: "Grow lights",
            subtitle: "When a window is not enough",
            symbolName: "lightbulb",
            tint: .leafGold,
            wikipediaTitle: "Grow light"
        ),
    ]
}

private struct CareGuideRow: View {
    let guide: CareGuide

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: guide.symbolName)
                .font(.subheadline)
                .foregroundStyle(guide.tint)
                .frame(width: 34, height: 34)
                .background(guide.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(guide.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.textPrimary)

                Text(guide.subtitle)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .padding(Metrics.cardPadding)
        .contentShape(Rectangle())
    }
}

#Preview("Explore") {
    NavigationStack {
        ExploreView()
    }
    .modelContainer(PreviewData.container)
}
