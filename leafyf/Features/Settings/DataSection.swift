import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// The Settings section that lets the garden leave the device and come back.
///
/// Built as a `Section` rather than a screen so `SettingsView` can drop it into its `Form`
/// beside the other sections, with no navigation of its own.
///
/// Each row owns the modifiers it needs. A `.sheet`, `.alert` or `.task` hung off the
/// `Section` itself is replicated onto every row the form renders, so the work — and the
/// presentation — happens once per row instead of once.
struct DataSection: View {
    @Query(sort: \Plant.dateAdded) private var plants: [Plant]

    var body: some View {
        Section {
            ExportRow(plants: plants)
            ImportRow()
            StorageRow(plants: plants)
        } header: {
            Text("Data")
        } footer: {
            Text("The backup holds names, schedules and care history as readable JSON. Photos and journal notes stay on this device.")
        }
    }
}

// MARK: - Export

/// Encoding the whole garden is too slow to do while laying out a row, so the file is built
/// once per change in the plant count and held until it is needed.
private struct ExportRow: View {
    let plants: [Plant]

    @State private var backup: BackupFile?

    var body: some View {
        Group {
            if let backup {
                ShareLink(
                    item: backup,
                    preview: SharePreview("Leafy backup", image: Image(systemName: "doc.text"))
                ) {
                    label
                }
            } else {
                label.foregroundStyle(.textSecondary)
            }
        }
        .task(id: plants.count) {
            backup = plants.isEmpty ? nil : BackupFile(plants: plants)
        }
    }

    private var label: some View {
        Label("Export backup", systemImage: "square.and.arrow.up")
    }
}

// MARK: - Import

private struct ImportRow: View {
    @Environment(\.modelContext) private var context

    @State private var isImporting = false
    @State private var result: ImportOutcome?

    var body: some View {
        Button {
            isImporting = true
        } label: {
            Label("Import backup", systemImage: "square.and.arrow.down")
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { outcome in
            handle(outcome)
        }
        .alert(result?.title ?? "", isPresented: showsResult, presenting: result) { _ in
            Button("OK", role: .cancel) {}
        } message: { outcome in
            Text(outcome.message)
        }
    }

    private var showsResult: Binding<Bool> {
        Binding(get: { result != nil }, set: { if !$0 { result = nil } })
    }

    private func handle(_ outcome: Result<URL, Error>) {
        do {
            let url = try outcome.get()
            let document = try DataExport.readBackup(at: url)
            let imported = try DataExport.merge(document, into: context)

            result = .imported(imported)
            if imported > 0 {
                Haptics.success()

                // The query has not caught up yet, so the freshly imported plants are
                // fetched back rather than rescheduling the list as it was before.
                let all = (try? context.fetch(FetchDescriptor<Plant>())) ?? []
                Task { await NotificationService.shared.reschedule(for: all) }
            }
        } catch is CancellationError {
            result = nil
        } catch {
            Haptics.warning()
            result = .failed(error.localizedDescription)
        }
    }
}

// MARK: - Outcome

private enum ImportOutcome: Identifiable {
    case imported(Int)
    case failed(String)

    var id: String {
        switch self {
        case .imported(let count): "imported-\(count)"
        case .failed(let message): "failed-\(message)"
        }
    }

    var title: String {
        switch self {
        case .imported: "Import finished"
        case .failed: "Import failed"
        }
    }

    /// A backup carries no photos, so the journal cannot come back with the plants. Saying so
    /// here is kinder than letting someone discover the gap weeks later.
    var message: String {
        switch self {
        case .imported(0): "Every plant in that backup is already here."
        case .imported(let count): "Imported \(Format.plants(count)). Journal photos stay on the original device."
        case .failed(let message): message
        }
    }
}

// MARK: - Storage

/// Counts come from the plants, the size comes from disk.
///
/// The counts are cheap. The size is not: the photos are `.externalStorage` blobs, so asking
/// a `Data` property for its `count` faults every full-size image into memory — hundreds of
/// megabytes, on the main actor, to print one line. The file system already knows the number.
private struct StorageRow: View {
    let plants: [Plant]

    @State private var summary: StorageSummary?

    var body: some View {
        LabeledContent("On this device") {
            Text(summary?.description ?? "…")
                .foregroundStyle(.textSecondary)
        }
        .task(id: plants.count) {
            var counted = StorageSummary(plants: plants)
            summary = counted

            let bytes = await Task.detached { StoreFootprint.bytes() }.value
            guard !Task.isCancelled else { return }

            counted.bytes = bytes
            summary = counted
        }
    }
}

private struct StorageSummary {
    let plants: Int
    let photos: Int
    /// Filled in once the disk scan returns; `nil` while it runs, and if it finds nothing.
    var bytes: Int64?

    init(plants list: [Plant]) {
        var photos = 0
        for plant in list {
            if plant.thumbnailData != nil { photos += 1 }
            photos += plant.journal.count
        }

        self.plants = list.count
        self.photos = photos
    }

    var description: String {
        let counts = "\(Format.plants(plants)), \(photos) \(photos == 1 ? "photo" : "photos")"
        guard let bytes, bytes > 0 else { return counts }
        return "\(counts) · \(bytes.formatted(.byteCount(style: .file)))"
    }
}

/// What the SwiftData store weighs on disk: the store files themselves plus the
/// `_EXTERNAL_DATA` folder where the photo blobs live.
///
/// Walking a directory tree is slow enough to keep off the main actor, hence `nonisolated`.
private enum StoreFootprint {
    nonisolated static func bytes() -> Int64? {
        let keys: [URLResourceKey] = [.isRegularFileKey, .totalFileAllocatedSizeKey, .fileSizeKey]
        guard let walker = FileManager.default.enumerator(
            at: URL.applicationSupportDirectory,
            includingPropertiesForKeys: keys
        ) else { return nil }

        var total: Int64 = 0
        var found = false

        for case let url as URL in walker {
            guard isStoreFile(url),
                  let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true,
                  let size = values.totalFileAllocatedSize ?? values.fileSize
            else { continue }

            total += Int64(size)
            found = true
        }

        return found ? total : nil
    }

    /// `default.store`, its `-wal`/`-shm` siblings, and anything inside an external-data folder.
    private nonisolated static func isStoreFile(_ url: URL) -> Bool {
        url.lastPathComponent.hasPrefix("default.store")
            || url.pathComponents.contains("_EXTERNAL_DATA")
    }
}

#Preview {
    NavigationStack {
        Form {
            DataSection()
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Settings")
    }
    .modelContainer(PreviewData.container)
}
