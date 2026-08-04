import SwiftData
import SwiftUI

struct PlantListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Plant.dateAdded, order: .reverse) private var plants: [Plant]

    @State private var searchText = ""
    @State private var selectedFilter: PlantFilter = .all
    @State private var isAddingPlant = false

    private var visiblePlants: [Plant] {
        let matches = searchText.isEmpty
            ? plants
            : plants.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
                    || $0.species.localizedCaseInsensitiveContains(searchText)
                    || $0.room.localizedCaseInsensitiveContains(searchText)
            }
        return matches.filter { selectedFilter.matches($0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !plants.isEmpty {
                        filterBar
                    }

                    if visiblePlants.isEmpty {
                        emptyState
                    } else {
                        ForEach(visiblePlants) { plant in
                            NavigationLink(value: plant) {
                                PlantRow(plant: plant)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Plants")
            .navigationDestination(for: Plant.self) { PlantDetailView(plant: $0) }
            .searchable(text: $searchText, prompt: "Search plants")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAddingPlant = true
                    } label: {
                        Label("Add plant", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $isAddingPlant) {
                PlantFormView(mode: .create)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(PlantFilter.allCases) { option in
                    Chip(title: option.title, isSelected: selectedFilter == option) {
                        withAnimation(.snappy) { selectedFilter = option }
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    @ViewBuilder
    private var emptyState: some View {
        if plants.isEmpty {
            ContentUnavailableView {
                Label("No plants yet", systemImage: "leaf")
            } description: {
                Text("Add your first plant and Leafy will keep track of when it needs care.")
            } actions: {
                Button("Add plant") { isAddingPlant = true }
                    .buttonStyle(.borderedProminent)
            }
            .padding(.top, 40)
        } else {
            ContentUnavailableView.search(text: searchText)
                .padding(.top, 40)
        }
    }
}

// MARK: - Filter

enum PlantFilter: String, CaseIterable, Identifiable {
    case all
    case needsCare
    case healthy
    case recentlyAdded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .needsCare: "Needs care"
        case .healthy: "Healthy"
        case .recentlyAdded: "New"
        }
    }

    func matches(_ plant: Plant) -> Bool {
        switch self {
        case .all:
            true
        case .needsCare:
            plant.mood == .overdue || plant.mood == .dueToday
        case .healthy:
            plant.mood == .thriving || plant.mood == .settlingIn
        case .recentlyAdded:
            plant.dateAdded > Calendar.current.date(byAdding: .day, value: -14, to: .now) ?? .distantPast
        }
    }
}

#Preview {
    PlantListView()
        .modelContainer(PreviewData.container)
}
