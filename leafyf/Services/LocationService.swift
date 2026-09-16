import CoreLocation
import Foundation
import Observation

// MARK: - Errors

enum LocationError: LocalizedError, Equatable {
    case denied
    case restricted
    case unavailable
    /// A previous request is still waiting on Core Location; a second one would orphan it.
    case busy

    var errorDescription: String? {
        switch self {
        case .denied: "Location access is off for Leafy."
        case .restricted: "Location is not available on this device."
        case .unavailable: "Could not work out where you are. Try searching for your city."
        case .busy: "Leafy is still looking for your location. Try again in a moment."
        }
    }

    /// Only a denial can be fixed by the user, and only in Settings.
    var isRecoverableInSettings: Bool { self == .denied }
}

// MARK: - Service

/// One-shot, when-in-use location for the weather card.
///
/// Leafy never tracks the user: it asks for a single fix when they tap "Use my current
/// location", turns it into a place name, and stops. Nothing is stored but the resulting
/// city and its coordinates.
@MainActor
@Observable
final class LocationService {
    static let shared = LocationService()

    private(set) var authorizationStatus: CLAuthorizationStatus
    private(set) var isLocating = false

    private let manager = CLLocationManager()
    private let proxy = DelegateProxy()

    /// Set only while an authorization prompt is on screen.
    private var authorizationWaiter: ((CLAuthorizationStatus) -> Void)?

    /// Core Location is free to never call back — the user can leave the prompt on screen,
    /// or a fix can simply never arrive indoors. Both waits give up rather than hang.
    private static let authorizationTimeout: Duration = .seconds(30)
    private static let locationTimeout: Duration = .seconds(20)

    private init() {
        authorizationStatus = manager.authorizationStatus
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
        manager.delegate = proxy
        proxy.onAuthorizationChange = { [weak self] status in
            MainActor.assumeIsolated { self?.handleAuthorizationChange(status) }
        }
    }

    private func handleAuthorizationChange(_ status: CLAuthorizationStatus) {
        authorizationStatus = status
        // `.notDetermined` also arrives once while the prompt is still on screen.
        guard status != .notDetermined else { return }
        authorizationWaiter?(status)
        authorizationWaiter = nil
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    /// Asks for permission if needed, takes a single fix and reverse-geocodes it.
    func currentPlace() async throws -> SavedPlace {
        guard !isLocating else { throw LocationError.busy }

        isLocating = true
        defer { isLocating = false }

        try await ensureAuthorized()
        let location = try await requestLocation()
        let name = await placeName(for: location)

        return SavedPlace(
            name: name.city,
            admin1: name.admin1,
            country: name.country,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    // MARK: - Authorization

    private func ensureAuthorized() async throws {
        switch authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return
        case .denied:
            throw LocationError.denied
        case .restricted:
            throw LocationError.restricted
        default:
            let status = try await requestAuthorization()
            guard status == .authorizedWhenInUse || status == .authorizedAlways else {
                throw status == .restricted ? LocationError.restricted : LocationError.denied
            }
        }
    }

    /// Waits for the system prompt to be answered. If nothing comes back in time the wait
    /// ends with whatever status Core Location holds, so the caller sees a denial rather
    /// than a spinner that never stops.
    private func requestAuthorization() async throws -> CLAuthorizationStatus {
        guard authorizationWaiter == nil else { throw LocationError.busy }

        return await withCheckedContinuation { continuation in
            let box = ResumeOnce(continuation)

            let timeout = Task { [weak self] in
                try? await Task.sleep(for: Self.authorizationTimeout)
                guard !Task.isCancelled, let self else { return }
                authorizationWaiter = nil
                box.resume(with: manager.authorizationStatus)
            }

            authorizationWaiter = { status in
                timeout.cancel()
                box.resume(with: status)
            }
            manager.requestWhenInUseAuthorization()
        }
    }

    // MARK: - Fix

    private func requestLocation() async throws -> CLLocation {
        guard proxy.onLocation == nil else { throw LocationError.busy }

        return try await withCheckedThrowingContinuation { continuation in
            let box = ResumeOnce(continuation)

            let timeout = Task { [weak self] in
                try? await Task.sleep(for: Self.locationTimeout)
                guard !Task.isCancelled, let self else { return }
                proxy.onLocation = nil
                box.resume(with: .failure(LocationError.unavailable))
            }

            proxy.onLocation = { [weak self] result in
                MainActor.assumeIsolated {
                    timeout.cancel()
                    self?.proxy.onLocation = nil
                    box.resume(with: result)
                }
            }
            manager.requestLocation()
        }
    }

    // MARK: - Naming

    /// A coordinate means nothing to the user, so the fix is turned into "Porto, Portugal".
    /// A geocoder failure is survivable — the weather still works, the label is vaguer.
    private func placeName(for location: CLLocation) async -> (city: String, admin1: String?, country: String?) {
        let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first

        let city = placemark?.locality ?? placemark?.subAdministrativeArea ?? placemark?.name
        return (city ?? "Current location", placemark?.administrativeArea, placemark?.country)
    }
}

// MARK: - Delegate

/// `CLLocationManagerDelegate` callbacks are not actor-isolated, so they land here and
/// hop onto the main actor (which is where this manager was created, and therefore where
/// Core Location delivers them) instead of forcing the service itself to be `nonisolated`.
private final class DelegateProxy: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
    var onLocation: ((Result<CLLocation, Error>) -> Void)?
    var onAuthorizationChange: ((CLAuthorizationStatus) -> Void)?

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        onAuthorizationChange?(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            onLocation?(.failure(LocationError.unavailable))
            return
        }
        onLocation?(.success(location))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        onLocation?(.failure(LocationError.unavailable))
    }
}

// MARK: - Continuation guard

/// Core Location can call back more than once; a continuation may only be resumed once.
private final class ResumeOnce<Success, Failure: Error> {
    private var continuation: CheckedContinuation<Success, Failure>?

    init(_ continuation: CheckedContinuation<Success, Failure>) {
        self.continuation = continuation
    }

    func resume(with value: Success) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

extension ResumeOnce where Failure == Error {
    func resume(with result: Result<Success, Error>) {
        continuation?.resume(with: result)
        continuation = nil
    }
}
