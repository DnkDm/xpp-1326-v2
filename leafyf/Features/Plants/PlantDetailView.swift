import PhotosUI
import SwiftData
import SwiftUI
import UIKit

struct PlantDetailView: View {
    @Bindable var plant: Plant

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var isEditing = false
    @State private var isConfirmingDelete = false
    @State private var photoItem: PhotosPickerItem?
    @State private var viewedEntry: JournalEntry?

    var body: some View {
        WidthReader { width in
            ScrollView {
                if sizeClass.usesPadLayout && width >= Metrics.padTwoColumnWidth {
                    twoColumnBody
                } else {
                    columnBody
                }
            }
            .coordinateSpace(name: HeroPhoto.space)
            .background(Color.canvas.ignoresSafeArea())
        }
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Edit plant", systemImage: "pencil") { isEditing = true }

                    ShareLink(item: PlantCareSheet.text(for: plant)) {
                        Label("Share care sheet", systemImage: "square.and.arrow.up")
                    }

                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label("Add journal photo", systemImage: "camera")
                    }

                    Divider()

                    Button("Delete plant", systemImage: "trash", role: .destructive) {
                        isConfirmingDelete = true
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            PlantFormView(mode: .edit(plant))
        }
        .confirmationDialog(
            "Delete \(plant.name)?",
            isPresented: $isConfirmingDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                PlantCare.delete(plant, from: context)
                dismiss()
            }
        } message: {
            Text("Its care history and journal photos are deleted too.")
        }
        .fullScreenCover(item: $viewedEntry) { entry in
            PhotoViewer(entry: entry)
        }
        .task(id: photoItem) {
            await addJournalPhoto()
        }
    }

    // MARK: - Layouts

    private var columnBody: some View {
        VStack(spacing: 0) {
            hero

            VStack(spacing: Metrics.sectionSpacing) {
                quickActions
                schedule
                if !plant.notes.isEmpty { notes }
                if !plant.journal.isEmpty { photoStrip }
                history
            }
            .padding(Metrics.screenPadding)
        }
    }

    /// iPad: care on the left, the record of what happened on the right.
    private var twoColumnBody: some View {
        VStack(spacing: 0) {
            hero

            HStack(alignment: .top, spacing: Metrics.padColumnSpacing) {
                VStack(spacing: Metrics.padSectionSpacing) {
                    quickActions
                    schedule
                    if !plant.notes.isEmpty { notes }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                VStack(spacing: Metrics.padSectionSpacing) {
                    if !plant.journal.isEmpty { photoStrip }
                    history
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .padding(Metrics.padScreenPadding)
            .maxContentWidth(Metrics.padContentWidth)
        }
    }

    // MARK: - Sections

    private var hero: some View {
        ZStack(alignment: .bottomLeading) {
            HeroPhoto(plant: plant, height: sizeClass.usesPadLayout ? 380 : 260)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.55)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    MoodBadge(mood: plant.mood)

                    Label(plant.room, systemImage: "house")
                        .font(.caption2)
                        .foregroundStyle(heroTextColor.opacity(0.85))
                }

                Text(plant.name)
                    .font(sizeClass.usesPadLayout ? .largeTitle.bold() : .title.bold())
                    .foregroundStyle(heroTextColor)

                Text(plant.displaySpecies)
                    .font(.subheadline)
                    .foregroundStyle(heroTextColor.opacity(0.85))
            }
            .padding(Metrics.padding(for: sizeClass))
        }
    }

    private var heroTextColor: Color {
        // Photo or illustration, the hero always carries a dark gradient under the title.
        .white
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            ForEach(CareKind.allCases) { kind in
                CareActionButton(kind: kind, showsPointerEffect: sizeClass.usesPadLayout) {
                    withAnimation(.snappy) {
                        PlantCare.log(kind, for: plant, in: context)
                    }
                }
            }
        }
    }

    private var schedule: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Care schedule")

            VStack(spacing: 14) {
                ForEach(CareKind.allCases) { kind in
                    ScheduleRow(plant: plant, kind: kind)
                }
            }
            .card()
        }
    }

    private var notes: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Notes")

            Text(plant.notes)
                .font(.body)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
        }
    }

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Journal", subtitle: "\(plant.journal.count) photos")

            if sizeClass.usesPadLayout {
                // A column has room to show the whole timeline at once, so no side-scrolling.
                LazyVGrid(columns: PadGrid.tiles(size: 116), alignment: .leading, spacing: 10) {
                    ForEach(sortedJournal) { entry in
                        journalTile(entry, size: 116)
                    }
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sortedJournal) { entry in
                            journalTile(entry, size: 120)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollClipDisabled()
            }
        }
    }

    private var sortedJournal: [JournalEntry] {
        plant.journal.sorted { $0.date > $1.date }
    }

    private func journalTile(_ entry: JournalEntry, size: CGFloat) -> some View {
        Button {
            viewedEntry = entry
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                JournalPhoto(entry: entry, size: size)

                Text(entry.date, format: .dateTime.day().month(.abbreviated))
                    .font(.caption2)
                    .foregroundStyle(.textSecondary)
            }
        }
        .buttonStyle(.card)
        .pointerLift(sizeClass.usesPadLayout)
        .accessibilityLabel("Journal photo, \(entry.date.formatted(.dateTime.day().month(.wide)))")
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "History")

            let entries = plant.careLog.sorted { $0.date > $1.date }.prefix(sizeClass.usesPadLayout ? 20 : 12)

            if entries.isEmpty {
                EmptyStateCard(
                    symbolName: "clock.arrow.circlepath",
                    title: "Nothing logged yet",
                    message: "Use the buttons above once you have cared for this plant."
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(entries)) { entry in
                        HStack(spacing: 12) {
                            Image(systemName: entry.kind.symbolName)
                                .font(.caption)
                                .foregroundStyle(entry.kind.tint)
                                .frame(width: 22)

                            Text(entry.kind.completedTitle)
                                .font(.subheadline)
                                .foregroundStyle(.textPrimary)

                            Spacer()

                            Text(entry.date, format: .dateTime.day().month(.abbreviated))
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                        }
                        .padding(.vertical, 11)
                        .padding(.horizontal, Metrics.cardPadding)

                        if entry.id != entries.last?.id {
                            Divider().overlay(Color.hairline)
                        }
                    }
                }
                .card(padding: 0)
            }
        }
    }

    // MARK: - Actions

    private func addJournalPhoto() async {
        guard let photoItem else { return }
        defer { self.photoItem = nil }

        guard let photo = await PhotoLibrary.process(photoItem) else { return }

        let entry = JournalEntry(photo: photo)
        entry.plant = plant
        context.insert(entry)
    }
}

// MARK: - Subviews

private struct CareActionButton: View {
    let kind: CareKind
    var showsPointerEffect = false
    let action: () -> Void

    /// Counts taps rather than tracking a flag, so the symbol bounces again on every log
    /// even when nothing else about the button changed. It also drives the single piece of
    /// haptic feedback for a log — `.sensoryFeedback` below, and nothing in the action.
    @State private var logCount = 0

    var body: some View {
        Button {
            logCount += 1
            action()
        } label: {
            VStack(spacing: 6) {
                Image(systemName: kind.symbolName)
                    .font(.title3)
                    .foregroundStyle(kind.tint)
                    .symbolEffect(.bounce, value: logCount)
                Text(kind.actionTitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.surface, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous)
                    .strokeBorder(kind.tint.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.card)
        .pointerLift(showsPointerEffect)
        .sensoryFeedback(.success, trigger: logCount)
        .accessibilityLabel("Log \(kind.title.lowercased())")
    }
}

private struct ScheduleRow: View {
    let plant: Plant
    let kind: CareKind

    private var isOverdue: Bool { plant.daysUntilDue(for: kind) < 0 }

    var body: some View {
        HStack(spacing: 14) {
            CareRing(
                progress: plant.progress(for: kind),
                tint: plant.urgencyTint(for: kind),
                size: 46,
                lineWidth: 5,
                symbolName: kind.symbolName
            )

            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(kind.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.textPrimary)

                    Spacer(minLength: 8)

                    Text("every \(Format.days(plant.interval(for: kind)))")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }

                Text(plant.statusText(for: kind))
                    .font(.caption)
                    .foregroundStyle(isOverdue ? Color.leafClay : .textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// The photo behind the plant's name, which stretches as the screen is pulled down.
///
/// A header that only ever sits still makes a detail screen feel like a document; letting it
/// follow the scroll costs one `GeometryReader` and makes the whole screen feel physical.
private struct HeroPhoto: View {
    static let space = "plantScroll"

    let plant: Plant
    let height: CGFloat

    var body: some View {
        GeometryReader { proxy in
            let stretch = max(proxy.frame(in: .named(Self.space)).minY, 0)

            photo
                .frame(width: proxy.size.width, height: height + stretch)
                .clipped()
                .offset(y: -stretch)
        }
        .frame(height: height)
    }

    private var photo: some View {
        Group {
            if let data = plant.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                // The species illustration fills in until the owner adds a real photo.
                Color.clear.overlay {
                    Image(plant.artworkName).resizable().scaledToFill()
                }
            }
        }
    }
}

struct JournalPhoto: View {
    let entry: JournalEntry
    var size: CGFloat

    var body: some View {
        Group {
            if let data = entry.thumbnailData ?? entry.photoData as Data?,
               let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.canvas
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Metrics.smallCorner, style: .continuous))
    }
}

#Preview {
    NavigationStack {
        PlantDetailView(plant: PreviewData.samplePlant)
    }
    .modelContainer(PreviewData.container)
}
