import PhotosUI
import SwiftData
import SwiftUI

/// Creates a new plant or edits an existing one. Edits are held in a draft and only
/// written to the model on save, so cancelling really cancels.
struct PlantFormView: View {
    enum Mode {
        case create
        case edit(Plant)
    }

    let mode: Mode

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var draft = PlantDraft()
    @State private var photoItem: PhotosPickerItem?
    @State private var isChoosingSpecies = false
    @State private var isLoadingPhoto = false

    private var isEditing: Bool {
        if case .edit = mode { return true }
        return false
    }

    private var canSave: Bool {
        !draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    photoSection
                    detailsSection
                    roomSection
                    scheduleSection
                    remindersSection
                    notesSection
                }
                .padding(Metrics.screenPadding)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit plant" : "New plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isChoosingSpecies) {
                PlantLibraryView { species in
                    draft.apply(species)
                    isChoosingSpecies = false
                }
            }
            .task(id: photoItem) { await loadPhoto() }
            .onAppear(perform: loadDraftIfNeeded)
        }
    }

    // MARK: - Sections

    private var photoSection: some View {
        VStack(spacing: 12) {
            PhotosPicker(selection: $photoItem, matching: .images) {
                PhotoPickerTile(
                    photo: draft.photo,
                    existingData: draft.existingPhotoData,
                    height: 200,
                    prompt: "Add a photo"
                )
                .overlay {
                    if isLoadingPhoto {
                        ProgressView()
                            .padding()
                            .background(.thinMaterial, in: Circle())
                    }
                }
            }
            .buttonStyle(.plain)

            Button("Pick from the plant library") { isChoosingSpecies = true }
                .font(.subheadline)
                .foregroundStyle(Color.leafGreen)
        }
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Details")

            VStack(spacing: 12) {
                LabeledField(title: "Name", text: $draft.name, prompt: "Monstera by the window")
                Divider().overlay(Color.hairline)
                LabeledField(title: "Species", text: $draft.species, prompt: "Monstera deliciosa")
            }
            .card()
        }
    }

    private var roomSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Room")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Room.presets, id: \.self) { room in
                        Chip(title: room, isSelected: draft.room == room) {
                            draft.room = room
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Care schedule", subtitle: "How often each task comes around")

            VStack(spacing: 16) {
                ForEach(CareKind.allCases) { kind in
                    IntervalStepper(
                        kind: kind,
                        value: Binding(
                            get: { draft.intervals[kind] ?? kind.defaultIntervalDays },
                            set: { draft.intervals[kind] = $0 }
                        )
                    )
                }
            }
            .card()
        }
    }

    private var remindersSection: some View {
        Toggle(isOn: $draft.remindersEnabled) {
            Label("Reminders", systemImage: "bell.fill")
                .foregroundStyle(.textPrimary)
        }
        .tint(.leafGreen)
        .card()
    }

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Notes")

            TextField(
                "Where it came from, quirks, anything worth remembering",
                text: $draft.notes,
                axis: .vertical
            )
            .lineLimit(3...8)
            .card()
        }
    }

    // MARK: - Actions

    private func loadDraftIfNeeded() {
        guard case .edit(let plant) = mode, draft.isEmpty else { return }
        draft = PlantDraft(plant: plant)
    }

    private func loadPhoto() async {
        guard let photoItem else { return }
        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            self.photoItem = nil
        }
        draft.photo = await PhotoLibrary.process(photoItem)
    }

    private func save() {
        let plant: Plant

        switch mode {
        case .create:
            plant = draft.makePlant()
            context.insert(plant)
        case .edit(let existing):
            draft.apply(to: existing)
            plant = existing
        }

        Task {
            if plant.remindersEnabled {
                await NotificationService.shared.requestAuthorization()
            }
            await NotificationService.shared.reschedule(for: [plant])
        }

        dismiss()
    }
}

// MARK: - Draft

private struct PlantDraft {
    var name = ""
    var species = ""
    var room = Room.default
    var notes = ""
    var remindersEnabled = true
    var intervals: [CareKind: Int] = Dictionary(
        uniqueKeysWithValues: CareKind.allCases.map { ($0, $0.defaultIntervalDays) }
    )
    var photo: ProcessedPhoto?
    var existingPhotoData: Data?

    var isEmpty: Bool { name.isEmpty && species.isEmpty && notes.isEmpty && photo == nil }

    init() {}

    init(plant: Plant) {
        name = plant.name
        species = plant.species
        room = plant.room
        notes = plant.notes
        remindersEnabled = plant.remindersEnabled
        intervals = Dictionary(uniqueKeysWithValues: CareKind.allCases.map { ($0, plant.interval(for: $0)) })
        existingPhotoData = plant.thumbnailData ?? plant.photoData
    }

    mutating func apply(_ species: PlantSpecies) {
        if name.isEmpty { name = species.name }
        self.species = species.name
        intervals[.watering] = species.wateringIntervalDays
        intervals[.fertilizing] = species.fertilizingIntervalDays
        intervals[.repotting] = species.repottingIntervalDays
    }

    func makePlant() -> Plant {
        let plant = Plant(
            name: trimmedName,
            species: species.trimmingCharacters(in: .whitespacesAndNewlines),
            room: room,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines),
            remindersEnabled: remindersEnabled,
            photo: photo
        )
        for kind in CareKind.allCases {
            plant.setInterval(intervals[kind] ?? kind.defaultIntervalDays, for: kind)
        }
        return plant
    }

    func apply(to plant: Plant) {
        plant.name = trimmedName
        plant.species = species.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.room = room
        plant.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        plant.remindersEnabled = remindersEnabled

        for kind in CareKind.allCases {
            plant.setInterval(intervals[kind] ?? kind.defaultIntervalDays, for: kind)
        }

        if let photo {
            plant.photoData = photo.full
            plant.thumbnailData = photo.thumbnail
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Fields

private struct LabeledField: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.textSecondary)

            TextField(prompt, text: $text)
                .font(.body)
                .foregroundStyle(.textPrimary)
        }
    }
}

private struct IntervalStepper: View {
    let kind: CareKind
    @Binding var value: Int

    var body: some View {
        Stepper(value: $value, in: kind.intervalRange) {
            HStack(spacing: 8) {
                Image(systemName: kind.symbolName)
                    .font(.caption)
                    .foregroundStyle(kind.tint)
                    .frame(width: 20)

                Text(kind.title)
                    .font(.subheadline)
                    .foregroundStyle(.textPrimary)

                Spacer()

                Text(Format.days(value))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.textPrimary)
                    .monospacedDigit()
            }
        }
        .accessibilityValue("every \(Format.days(value))")
    }
}

#Preview {
    PlantFormView(mode: .create)
        .modelContainer(PreviewData.container)
}
