import SwiftData
import SwiftUI
import UIKit

struct JournalView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Query(sort: \Plant.name) private var plants: [Plant]
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]

    @State private var isComposing = false
    @State private var plantFilter: Plant?
    @State private var viewedEntry: JournalEntry?

    private let calendar = Calendar.current

    private var visibleEntries: [JournalEntry] {
        guard let plantFilter else { return entries }
        return entries.filter { $0.plant?.id == plantFilter.id }
    }

    /// Newest month first, matching the query order, so the timeline reads backwards from today.
    private var months: [JournalMonth] {
        Dictionary(grouping: visibleEntries) { calendar.startOfMonth(for: $0.date) }
            .map { JournalMonth(start: $0.key, entries: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.start > $1.start }
    }

    /// Photos want to be big on an iPad and still fit three to a row on a phone.
    private var tileSize: CGFloat {
        sizeClass.usesPadLayout ? 150 : 104
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if plants.count > 1 {
                    filterBar
                }

                if visibleEntries.isEmpty {
                    emptyState
                } else {
                    timeline
                }
            }
            .padding(Metrics.padding(for: sizeClass))
            .maxContentWidth(Metrics.padContentWidth, enabled: sizeClass.usesPadLayout)
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
                .keyboardShortcut("n", modifiers: .command)
            }
        }
        .sheet(isPresented: $isComposing) {
            JournalComposerView(plants: plants)
        }
        .fullScreenCover(item: $viewedEntry) { entry in
            PhotoViewer(entry: entry)
        }
    }

    // MARK: - Timeline

    /// A grid rather than a stack of cards: the journal is about noticing change between
    /// photos, and that only works when several of them are on screen at once. The month
    /// headers stay pinned so it is always clear which stretch of time is being looked at.
    private var timeline: some View {
        LazyVStack(alignment: .leading, spacing: 18, pinnedViews: [.sectionHeaders]) {
            ForEach(months) { month in
                Section {
                    LazyVGrid(
                        columns: PadGrid.tiles(size: tileSize, spacing: 8),
                        alignment: .leading,
                        spacing: 8
                    ) {
                        ForEach(month.entries) { entry in
                            tile(for: entry)
                        }
                    }
                } header: {
                    MonthHeader(start: month.start, count: month.entries.count)
                }
            }
        }
    }

    private func tile(for entry: JournalEntry) -> some View {
        Button {
            viewedEntry = entry
        } label: {
            JournalTile(entry: entry, size: tileSize)
        }
        .buttonStyle(.card)
        .pointerLift(sizeClass.usesPadLayout)
        .contextMenu {
            Button("Delete entry", systemImage: "trash", role: .destructive) {
                withAnimation(.snappy) { context.delete(entry) }
            }
        }
        .accessibilityLabel("\(entry.plant?.name ?? "Removed plant"), \(entry.date.formatted(.dateTime.day().month(.wide)))")
        .accessibilityValue(entry.caption)
    }

    // MARK: - Chrome

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

// MARK: - Month

private struct JournalMonth: Identifiable {
    let start: Date
    let entries: [JournalEntry]

    var id: Date { start }
}

private struct MonthHeader: View {
    let start: Date
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(start, format: .dateTime.month(.wide).year())
                .font(.headline)
                .foregroundStyle(.textPrimary)

            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.leafGreen)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Color.leafGreen.opacity(0.14), in: Capsule())

            Spacer()
        }
        .padding(.vertical, 6)
        // Pinned headers scroll over the photos below them, so they need the canvas
        // behind them rather than letting a leaf show through the words.
        .background(Color.canvas)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Tile

private struct JournalTile: View {
    let entry: JournalEntry
    let size: CGFloat

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            photo

            LinearGradient(
                colors: [.clear, .black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            HStack(spacing: 4) {
                Text(entry.plant?.name ?? "Removed")
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)

                if !entry.caption.isEmpty {
                    Image(systemName: "text.quote")
                        .font(.system(size: 8))
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 5, y: 2)
    }

    private var photo: some View {
        Group {
            if let data = entry.thumbnailData ?? entry.photoData as Data?,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.surfaceMuted
            }
        }
        .frame(width: size, height: size)
        .clipped()
    }
}

#Preview {
    NavigationStack {
        JournalView()
    }
    .modelContainer(PreviewData.container)
}
