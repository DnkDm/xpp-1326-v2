import SwiftUI
import UIKit

/// Sheet for choosing the place the weather card reports on: one tap for "where I am now",
/// or a search for anywhere else. Presented from Settings and from the Today card's CTA.
struct PlacePickerView: View {
    var store: WeatherStore = .shared
    var locationService: LocationService = .shared

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var query = ""
    @State private var results: [PlaceResult] = []
    @State private var searchState: SearchState = .idle
    @State private var locationError: LocationError?
    @State private var isLocating = false

    private enum SearchState: Equatable {
        case idle
        case searching
        case done
        case failed(String)
    }

    var body: some View {
        NavigationStack {
            List {
                currentLocationSection
                resultsSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "City or town")
            .autocorrectionDisabled()
            // `.task(id:)` restarts on every keystroke, so the sleep below debounces the
            // search and cancellation cleans up the request that is no longer wanted.
            .task(id: query) { await search() }
        }
    }

    // MARK: - Sections

    private var currentLocationSection: some View {
        Section {
            Button {
                Task { await useCurrentLocation() }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "location.fill")
                        .foregroundStyle(Color.leafGreen)
                        .frame(width: 22)

                    Text("Use my current location")
                        .foregroundStyle(.textPrimary)

                    Spacer()

                    if isLocating {
                        ProgressView()
                    }
                }
            }
            .disabled(isLocating)

            if let locationError {
                LocationErrorRow(error: locationError) { openSettings() }
            }
        } footer: {
            Text("Leafy asks for your location once, only to look up the local forecast.")
        }
    }

    @ViewBuilder
    private var resultsSection: some View {
        switch searchState {
        case .idle:
            EmptyView()

        case .searching:
            Section {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Searching…")
                        .foregroundStyle(.textSecondary)
                }
            }

        case .failed(let message):
            Section {
                Label(message, systemImage: "wifi.exclamationmark")
                    .foregroundStyle(.textSecondary)
            }

        case .done where results.isEmpty:
            Section {
                Label("No places match “\(query)”", systemImage: "magnifyingglass")
                    .foregroundStyle(.textSecondary)
            }

        case .done:
            Section("Results") {
                ForEach(results) { result in
                    Button { choose(result.place) } label: {
                        PlaceRow(result: result)
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func search() async {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            results = []
            searchState = .idle
            return
        }

        // Long enough that a fast typist makes one request, short enough to feel live.
        try? await Task.sleep(for: .milliseconds(350))
        guard !Task.isCancelled else { return }

        searchState = .searching

        do {
            let found = try await GeocodingService.search(trimmed)
            guard !Task.isCancelled else { return }
            withAnimation(.snappy) {
                results = found
                searchState = .done
            }
        } catch is CancellationError {
            return
        } catch {
            let message = (error as? WeatherError)?.errorDescription ?? "Search is unavailable right now."
            searchState = .failed(message)
        }
    }

    private func useCurrentLocation() async {
        isLocating = true
        locationError = nil
        defer { isLocating = false }

        do {
            let place = try await locationService.currentPlace()
            choose(place)
        } catch let error as LocationError {
            withAnimation(.snappy) { locationError = error }
        } catch {
            withAnimation(.snappy) { locationError = .unavailable }
        }
    }

    private func choose(_ place: SavedPlace) {
        store.use(place)
        dismiss()
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}

// MARK: - Rows

private struct PlaceRow: View {
    let result: PlaceResult

    var body: some View {
        HStack(spacing: 12) {
            Text(result.flag)
                .font(.title3)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(result.name)
                    .foregroundStyle(.textPrimary)

                if !result.place.subtitle.isEmpty {
                    Text(result.place.subtitle)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }

            Spacer(minLength: 0)
        }
        .contentShape(Rectangle())
    }
}

private struct LocationErrorRow: View {
    let error: LocationError
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(error.errorDescription ?? "Location is unavailable.", systemImage: "location.slash")
                .font(.subheadline)
                .foregroundStyle(Color.leafClay)

            if error.isRecoverableInSettings {
                Button("Open Settings", action: onOpenSettings)
                    .font(.subheadline.weight(.semibold))
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview("Picker") {
    PlacePickerView(store: .previewStore(snapshot: nil, place: nil))
}
