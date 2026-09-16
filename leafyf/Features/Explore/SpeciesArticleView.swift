import SwiftData
import SwiftUI

/// One plant or care topic: the Wikipedia summary, Leafy's own care numbers when the
/// article came from the catalog, and the two things worth doing next — read the whole
/// article, or grow one.
struct SpeciesArticleView: View {
    let request: ArticleRequest
    /// Set when the screen is reached from the species picker, where "add a plant" would
    /// open a second form on top of the one already being filled in. Picking the species
    /// hands it back to that form instead.
    var onUseSpecies: ((PlantSpecies) -> Void)?

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var article: LoadState<SpeciesArticle> = .idle
    @State private var retryToken = 0
    @State private var browserLink: BrowserLink?
    @State private var isAddingPlant = false

    init(request: ArticleRequest, onUseSpecies: ((PlantSpecies) -> Void)? = nil) {
        self.request = request
        self.onUseSpecies = onUseSpecies
    }

    init(species: PlantSpecies, onUseSpecies: ((PlantSpecies) -> Void)? = nil) {
        self.init(request: ArticleRequest(species: species), onUseSpecies: onUseSpecies)
    }

    init(wikipediaTitle: String, displayName: String? = nil) {
        self.init(request: ArticleRequest(wikipediaTitle: wikipediaTitle, displayName: displayName))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Metrics.spacing(for: sizeClass)) {
                // On the phone the lead image runs edge to edge, like the plant detail hero;
                // an iPad column keeps it inset and rounded so it lines up with the cards.
                hero
                    .padding(sizeClass.usesPadLayout ? Metrics.padScreenPadding : 0)
                    .padding(.bottom, sizeClass.usesPadLayout ? -Metrics.padScreenPadding : 0)

                VStack(alignment: .leading, spacing: Metrics.spacing(for: sizeClass)) {
                    heading

                    if let species = request.species {
                        CareFactsCard(species: species)
                    }

                    content
                    actions
                    attribution
                }
                .padding(Metrics.padding(for: sizeClass))
            }
            .maxContentWidth(Metrics.padReadingWidth, enabled: sizeClass.usesPadLayout)
        }
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(article.value?.title ?? request.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: retryToken) { await load() }
        .sheet(item: $browserLink) { link in
            BrowserScreen(url: link.url)
        }
        .sheet(isPresented: $isAddingPlant) {
            PlantFormView(mode: .create, initialSpecies: request.species)
        }
    }

    // MARK: - Header

    /// The lead image when there is one. A tinted emoji panel stands in for catalog
    /// species while the summary loads, so the screen never opens on a blank rectangle.
    private var hero: some View {
        ZStack {
            LinearGradient(
                colors: [Color.leafGreen.opacity(0.18), Color.leafMint.opacity(0.10)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            if let url = article.value?.imageURL {
                AsyncImage(url: url, transaction: Transaction(animation: .snappy)) { phase in
                    if let image = phase.image {
                        // Laid over a clear fill so the image's own size never proposes a width
                        // wider than the screen to the surrounding column.
                        Color.clear.overlay { image.resizable().scaledToFill() }
                    } else if phase.error != nil {
                        placeholderSymbol
                    } else {
                        // The illustration stays underneath while the lead photo arrives,
                        // so the hero never collapses to a spinner on a blank panel.
                        placeholderSymbol.overlay { ProgressView().tint(.white) }
                    }
                }
            } else {
                placeholderSymbol
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: sizeClass.usesPadLayout ? 300 : 260)
        .clipped()
        .clipShape(
            RoundedRectangle(
                cornerRadius: sizeClass.usesPadLayout ? Metrics.corner : 0,
                style: .continuous
            )
        )
        .accessibilityHidden(true)
    }

    private var placeholderSymbol: some View {
        Group {
            if let species = request.species {
                Color.clear.overlay {
                    Image(species.artworkName).resizable().scaledToFill()
                }
            } else {
                Image(systemName: "book.pages")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.leafGreen)
            }
        }
    }

    private var heading: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(article.value?.title ?? request.displayName)
                .font(sizeClass.usesPadLayout ? .largeTitle.bold() : .title2.bold())
                .foregroundStyle(.textPrimary)

            if let subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Wikipedia's one-liner, or the botanical name when the article has none.
    private var subtitle: String? {
        if let description = article.value?.description, !description.isEmpty {
            return description.prefix(1).localizedUppercase + description.dropFirst()
        }
        return request.species?.scientificName
    }

    // MARK: - Body text

    @ViewBuilder
    private var content: some View {
        switch article {
        case .idle, .loading:
            VStack(alignment: .leading, spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.hairline)
                        .frame(height: 12)
                }
            }
            .card()
            .redacted(reason: .placeholder)

        case .loaded(let article) where article.extract.isEmpty:
            summaryFallback

        case .loaded(let article):
            Text(article.extract)
                .font(.body)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

        case .failed(let error):
            VStack(alignment: .leading, spacing: 12) {
                Label(error.message, systemImage: error.symbolName)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)

                Button("Try again") { retryToken += 1 }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.leafGreen)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            // The catalog blurb is still worth showing while Wikipedia is unreachable.
            summaryFallback
        }
    }

    @ViewBuilder
    private var summaryFallback: some View {
        if let species = request.species {
            Text(species.summary)
                .font(.body)
                .foregroundStyle(.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            if let species = request.species {
                Button {
                    if let onUseSpecies {
                        onUseSpecies(species)
                    } else {
                        isAddingPlant = true
                    }
                } label: {
                    Label(
                        onUseSpecies == nil ? "Add to my plants" : "Use this plant",
                        systemImage: "plus.circle.fill"
                    )
                }
                .buttonStyle(.primary)
            }

            Button {
                if let url = pageURL { browserLink = BrowserLink(url: url) }
            } label: {
                Label("Read full article", systemImage: "safari")
                    .font(.headline)
                    .foregroundStyle(Color.leafGreen)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color.surface, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                            .strokeBorder(Color.leafGreen.opacity(0.35), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .disabled(pageURL == nil)
        }
    }

    /// The loaded mobile URL when there is one, otherwise the address the title implies —
    /// so the button works even if the summary request failed.
    private var pageURL: URL? {
        article.value?.pageURL ?? WikipediaService.webPageURL(for: request.wikipediaTitle)
    }

    private var attribution: some View {
        Text("Text from Wikipedia, available under CC BY-SA.")
            .font(.caption2)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading

    private func load() async {
        if article.value == nil { article = .loading }

        do {
            let summary = try await WikipediaService.summary(for: request.wikipediaTitle)
            try Task.checkCancellation()
            withAnimation(.snappy) { article = .loaded(summary) }
        } catch {
            let failure = APIError.wrapping(error)
            guard !failure.isCancellation else { return }
            withAnimation(.snappy) { article = .failed(failure) }
        }
    }
}

// MARK: - Care facts

/// Leafy's own numbers for a catalog species, next to the encyclopaedia text.
private struct CareFactsCard: View {
    let species: PlantSpecies

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Leafy's starting schedule", subtitle: species.light)

            HStack(spacing: 10) {
                ForEach(CareKind.allCases) { kind in
                    fact(kind)
                }
            }
        }
        .card()
    }

    private func fact(_ kind: CareKind) -> some View {
        VStack(spacing: 6) {
            Image(systemName: kind.symbolName)
                .font(.subheadline)
                .foregroundStyle(kind.tint)

            Text(Format.days(interval(kind)))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.textPrimary)
                .monospacedDigit()

            Text(kind.title)
                .font(.caption2)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(kind.tint.opacity(0.10), in: RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(kind.title) every \(Format.days(interval(kind)))")
    }

    private func interval(_ kind: CareKind) -> Int {
        switch kind {
        case .watering: species.wateringIntervalDays
        case .fertilizing: species.fertilizingIntervalDays
        case .repotting: species.repottingIntervalDays
        }
    }
}

#Preview("Species") {
    NavigationStack {
        SpeciesArticleView(species: PlantSpecies.catalog[0])
    }
    .modelContainer(PreviewData.container)
}

#Preview("Care guide") {
    NavigationStack {
        SpeciesArticleView(wikipediaTitle: "Root rot", displayName: "Root rot")
    }
    .modelContainer(PreviewData.container)
}
