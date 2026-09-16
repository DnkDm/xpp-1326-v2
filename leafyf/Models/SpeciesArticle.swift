import Foundation

// MARK: - Article

/// A Wikipedia page summary, reduced to the handful of fields Leafy shows.
///
/// Kept free of `Decodable` on purpose: the REST payload is deeply nested and changes
/// shape between endpoints, so `WikipediaService` owns the decoding and hands back this
/// flat value instead.
struct SpeciesArticle: Identifiable, Hashable, Sendable {
    /// Canonical article title, which may differ from the one that was requested when
    /// Wikipedia followed a redirect.
    let title: String
    /// One-line description ("species of plant"), missing on many articles.
    let description: String?
    let extract: String
    /// Small square-ish crop for lists.
    let thumbnailURL: URL?
    /// Full-size lead image for the hero.
    let imageURL: URL?
    /// Mobile-formatted page, which is what the in-app browser should open.
    let pageURL: URL?

    var id: String { title }
}

// MARK: - Search result

/// One row of a Wikipedia search response. The snippet arrives as HTML and is already
/// stripped to plain text by the time it reaches a view.
struct WikipediaSearchResult: Identifiable, Hashable, Sendable {
    let title: String
    let snippet: String
    /// Filled in by a second, batched request — the search endpoint returns no images.
    var thumbnailURL: URL?

    var id: String { title }
}

// MARK: - Article request

/// What a `SpeciesArticleView` was opened for.
///
/// A single `Hashable` value rather than separate initialisers so it can be pushed with
/// `NavigationLink(value:)` and resolved by one `.navigationDestination`.
struct ArticleRequest: Hashable, Identifiable, Sendable {
    /// Exact Wikipedia article title, spaces and all.
    let wikipediaTitle: String
    /// Shown in the navigation bar while the summary is still loading.
    let displayName: String
    /// Set when the article was opened from the built-in catalog, which lets the screen
    /// show Leafy's own care intervals alongside the encyclopaedia text.
    let species: PlantSpecies?

    var id: String { wikipediaTitle }

    init(species: PlantSpecies) {
        self.wikipediaTitle = species.wikipediaTitle
        self.displayName = species.name
        self.species = species
    }

    init(wikipediaTitle: String, displayName: String? = nil) {
        self.wikipediaTitle = wikipediaTitle
        self.displayName = displayName ?? wikipediaTitle
        self.species = nil
    }

    init(searchResult: WikipediaSearchResult) {
        self.init(wikipediaTitle: searchResult.title)
    }
}
