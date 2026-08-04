import PhotosUI
import SwiftData
import SwiftUI

struct JournalComposerView: View {
    let plants: [Plant]

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlant: Plant?
    @State private var photoItem: PhotosPickerItem?
    @State private var photo: ProcessedPhoto?
    @State private var caption = ""
    @State private var isLoadingPhoto = false

    private var canSave: Bool { selectedPlant != nil && photo != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Metrics.sectionSpacing) {
                    plantPicker
                    photoPicker
                    captionField
                }
                .padding(Metrics.screenPadding)
            }
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("New entry")
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
            .task(id: photoItem) { await loadPhoto() }
            .onAppear {
                if selectedPlant == nil { selectedPlant = plants.first }
            }
        }
    }

    private var plantPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Plant")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(plants) { plant in
                        Chip(title: plant.name, isSelected: selectedPlant?.id == plant.id) {
                            selectedPlant = plant
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 2)
            }
            .scrollClipDisabled()
        }
    }

    private var photoPicker: some View {
        PhotosPicker(selection: $photoItem, matching: .images) {
            PhotoPickerTile(photo: photo, existingData: nil, height: 240, prompt: "Choose a photo")
                .overlay {
                    if isLoadingPhoto {
                        ProgressView()
                            .padding()
                            .background(.thinMaterial, in: Circle())
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Note", subtitle: "Optional")

            TextField("A new leaf unfurled today", text: $caption, axis: .vertical)
                .lineLimit(2...6)
                .card()
        }
    }

    private func loadPhoto() async {
        guard let photoItem else { return }
        isLoadingPhoto = true
        defer {
            isLoadingPhoto = false
            self.photoItem = nil
        }
        photo = await PhotoLibrary.process(photoItem)
    }

    private func save() {
        guard let plant = selectedPlant, let photo else { return }

        let entry = JournalEntry(
            photo: photo,
            caption: caption.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        entry.plant = plant
        context.insert(entry)

        dismiss()
    }
}

#Preview {
    JournalComposerView(plants: [PreviewData.samplePlant])
        .modelContainer(PreviewData.container)
}
