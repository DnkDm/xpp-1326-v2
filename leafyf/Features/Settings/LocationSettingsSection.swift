import SwiftUI
import UIKit

/// The weather block of the Settings form. Returns a bare `Section` so the coordinator can
/// drop it into `SettingsView`'s `Form` wherever it belongs.
struct LocationSettingsSection: View {
    var store: WeatherStore = .shared
    var locationService: LocationService = .shared

    @Environment(\.openURL) private var openURL

    @State private var isShowingPicker = false
    @State private var isLocating = false
    @State private var locationError: LocationError?

    var body: some View {
        Section {
            if let place = store.place {
                savedPlaceRow(place)
                currentLocationButton
                pickerButton("Change city")
                Button("Remove location", role: .destructive) {
                    withAnimation(.snappy) { store.clearPlace() }
                }
            } else {
                currentLocationButton
                pickerButton("Search for a city")
            }

            if let locationError {
                errorRow(locationError)
            }
        } header: {
            Text("Weather")
        } footer: {
            Text("Leafy checks the local forecast to suggest when heat, dry air or short days change what your plants need. Coordinates go to Open-Meteo only, and nothing is stored anywhere else.")
        }
    }

    // MARK: - Rows

    /// Only one of these is ever on screen, so the sheet rides on the row that opens it
    /// rather than on the `Section`, which would hand every row its own presenter.
    private func pickerButton(_ title: String) -> some View {
        Button(title) { isShowingPicker = true }
            .sheet(isPresented: $isShowingPicker) {
                PlacePickerView(store: store, locationService: locationService)
            }
    }

    private func savedPlaceRow(_ place: SavedPlace) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName)
                .font(.title3)
                .foregroundStyle(Color.leafGreen)
                .frame(width: 26)

            VStack(alignment: .leading, spacing: 2) {
                Text(place.name)
                    .foregroundStyle(.textPrimary)

                Text(subtitle(for: place))
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }

            Spacer(minLength: 0)

            if store.isLoading {
                ProgressView()
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var currentLocationButton: some View {
        Button {
            Task { await useCurrentLocation() }
        } label: {
            HStack {
                Text("Use current location")
                Spacer()
                if isLocating { ProgressView() }
            }
        }
        .disabled(isLocating)
    }

    private func errorRow(_ error: LocationError) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(error.errorDescription ?? "Location is unavailable.")
                .font(.caption)
                .foregroundStyle(Color.leafClay)

            if error.isRecoverableInSettings {
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .font(.caption.weight(.semibold))
            }
        }
    }

    // MARK: - Detail

    /// The saved place is worth more than its name here: showing the current conditions
    /// proves the forecast is really working for that location.
    private func subtitle(for place: SavedPlace) -> String {
        guard let snapshot = store.snapshot, snapshot.placeID == place.id else {
            return place.subtitle.isEmpty ? "Weather location" : place.subtitle
        }
        return "\(snapshot.temperatureText) · \(snapshot.condition.label) · updated \(snapshot.ageText)"
    }

    private var symbolName: String {
        guard let snapshot = store.snapshot else { return "location.fill" }
        return snapshot.condition.symbolName(isDaytime: snapshot.isDaytime)
    }

    // MARK: - Actions

    private func useCurrentLocation() async {
        isLocating = true
        locationError = nil
        defer { isLocating = false }

        do {
            let place = try await locationService.currentPlace()
            withAnimation(.snappy) { store.use(place) }
        } catch let error as LocationError {
            withAnimation(.snappy) { locationError = error }
        } catch {
            withAnimation(.snappy) { locationError = .unavailable }
        }
    }
}

#Preview("With place") {
    Form {
        LocationSettingsSection(store: .previewStore())
    }
    .scrollContentBackground(.hidden)
    .background(Color.canvas.ignoresSafeArea())
}

#Preview("No place") {
    Form {
        LocationSettingsSection(store: .previewStore(snapshot: nil, place: nil))
    }
    .scrollContentBackground(.hidden)
    .background(Color.canvas.ignoresSafeArea())
}
