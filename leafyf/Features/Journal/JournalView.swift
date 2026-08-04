import SwiftData
import SwiftUI
import UIKit

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Plant.name) private var plants: [Plant]
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var isComposing = false
    @State private var plantFilter: Plant?

    private var visibleEntries: [JournalEntry] {
        guard let plantFilter else { return entries }
        return entries.filter { $0.plant?.id == plantFilter.id }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if plants.count > 1 {
                        filterBar
                    }

                    if visibleEntries.isEmpty {
                        emptyState
                    } else {
                        ForEach(visibleEntries) { entry in
                            JournalCard(entry: entry) {
                                context.delete(entry)
                            }
                        }
                    }
                }
                .padding(Metrics.screenPadding)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Journal")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isComposing = true
                    } label: {
                        Label("New entry", systemImage: "plus")
                    }
                    .disabled(plants.isEmpty)
                }
            }
            .sheet(isPresented: $isComposing) {
                JournalComposerView(plants: plants)
            }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Chip(title: "All", isSelected: plantFilter == nil) {
                    withAnimation(.snappy) { plantFilter = nil }
                }

                ForEach(plants) { plant in
                    Chip(title: plant.name, isSelected: plantFilter?.id == plant.id) {
                        withAnimation(.snappy) { plantFilter = plant }
                    }
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No entries yet", systemImage: "photo.stack")
        } description: {
            Text(
                plants.isEmpty
                    ? "Add a plant first, then photograph it every few weeks to build a timeline."
                    : "Photograph a plant every few weeks and watch the changes add up."
            )
        } actions: {
            if !plants.isEmpty {
                Button("Add entry") { isComposing = true }
                    .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }
}

// MARK: - Card

private struct JournalCard: View {
    let entry: JournalEntry
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(entry.plant?.name ?? "Removed plant")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)

                Spacer()

                Text(entry.date, format: .dateTime.day().month(.abbreviated).year())
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }

            if let image = UIImage(data: entry.photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 220)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))
            }

            if !entry.caption.isEmpty {
                Text(entry.caption)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
            }
        }
        .card()
        .contextMenu {
            Button("Delete entry", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }
}

#Preview {
    JournalView()
        .modelContainer(PreviewData.container)
}
