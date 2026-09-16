import Foundation
import Observation

/// Owns everything weather-related the UI observes: the saved place, the last snapshot,
/// whether a fetch is in flight and what went wrong last time.
///
/// A singleton rather than an environment value because the Today card, the settings
/// section and the place picker all need the same instance, and none of them is close
/// enough to the others in the view tree for one `.environment(_:)` to cover them.
@MainActor
@Observable
final class WeatherStore {
    static let shared = WeatherStore()

    private(set) var place: SavedPlace?
    private(set) var snapshot: WeatherSnapshot?
    private(set) var isLoading = false
    private(set) var error: WeatherError?

    private let defaults: UserDefaults
    /// Held so a second `refresh()` joins the first instead of starting a duplicate request.
    private var activeFetch: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        place = Self.decode(SavedPlace.self, from: defaults, key: StorageKey.savedPlace)
        snapshot = Self.decode(WeatherSnapshot.self, from: defaults, key: StorageKey.weatherCache)

        // A cached snapshot for a place the user has since changed is worse than nothing:
        // it would show the old city's weather under the new city's name.
        if snapshot?.placeID != place?.id { snapshot = nil }
    }

    var hasPlace: Bool { place != nil }

    /// True only while the very first fetch for a place is running, which is the one case
    /// that needs a placeholder card rather than a quiet background refresh.
    var isLoadingWithoutData: Bool { isLoading && snapshot == nil }

    // MARK: - Place

    /// Re-picking the same place still counts: the name or region may have been corrected,
    /// and it is how the user retries after a fetch that failed. Only the cached snapshot
    /// is kept in that case, because it really does belong to this place.
    func use(_ place: SavedPlace) {
        let isSamePlace = place.id == self.place?.id

        self.place = place
        persist(place, key: StorageKey.savedPlace)

        error = nil

        if !isSamePlace {
            snapshot = nil
            defaults.removeObject(forKey: StorageKey.weatherCache)
        }

        Task { await refresh(force: true) }
    }

    func clearPlace() {
        activeFetch?.cancel()
        activeFetch = nil
        place = nil
        snapshot = nil
        error = nil
        isLoading = false
        defaults.removeObject(forKey: StorageKey.savedPlace)
        defaults.removeObject(forKey: StorageKey.weatherCache)
    }

    // MARK: - Refresh

    /// Fetches only when there is something to gain: no data yet, data older than half an
    /// hour, or the caller insisting (pull to refresh).
    func refresh(force: Bool = false) async {
        guard let place else { return }

        if !force, let snapshot, snapshot.placeID == place.id, !snapshot.isStale {
            return
        }

        if let activeFetch {
            await activeFetch.value
            return
        }

        let task = Task { await load(place) }
        activeFetch = task
        await task.value
        activeFetch = nil
    }

    private func load(_ place: SavedPlace) async {
        isLoading = true
        defer { isLoading = false }

        do {
            let fresh = try await WeatherService.snapshot(for: place)
            guard !Task.isCancelled else { return }

            snapshot = fresh
            error = nil
            persist(fresh, key: StorageKey.weatherCache)
        } catch is CancellationError {
            return
        } catch let failure as WeatherError {
            error = failure
        } catch {
            self.error = .badResponse
        }
    }

    // MARK: - Persistence

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, from defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}

// MARK: - Preview

extension WeatherStore {
    /// A store that already has a place and a snapshot, so previews and Xcode canvases
    /// render the finished card instead of the empty-state CTA.
    static func previewStore(
        snapshot: WeatherSnapshot? = .preview,
        place: SavedPlace? = .preview,
        isLoading: Bool = false,
        error: WeatherError? = nil
    ) -> WeatherStore {
        let store = WeatherStore(defaults: UserDefaults(suiteName: "leafy.preview") ?? .standard)
        store.place = place
        store.snapshot = snapshot
        store.isLoading = isLoading
        store.error = error
        return store
    }
}
