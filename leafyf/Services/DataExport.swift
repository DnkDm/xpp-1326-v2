import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Documents

/// The whole garden as plain JSON: schedules, care history and journal captions.
///
/// Photos are deliberately left out. They are by far the biggest thing in the store, and a
/// backup that can be mailed to yourself or dropped in Files is worth more than one that
/// cannot leave the device — the text is what is impossible to reconstruct from memory.
nonisolated struct BackupDocument: Codable, Hashable {
    /// Bumped whenever the shape changes, so a future import can tell what it is reading.
    static let currentVersion = 1

    var version: Int
    var exportedAt: Date
    var plants: [BackupPlant]

    init(version: Int = BackupDocument.currentVersion, exportedAt: Date = .now, plants: [BackupPlant]) {
        self.version = version
        self.exportedAt = exportedAt
        self.plants = plants
    }
}

nonisolated struct BackupPlant: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var species: String
    var room: String
    var notes: String
    var dateAdded: Date
    var remindersEnabled: Bool

    var wateringIntervalDays: Int
    var fertilizingIntervalDays: Int
    var repottingIntervalDays: Int

    var lastWatered: Date?
    var lastFertilized: Date?
    var lastRepotted: Date?

    var careLog: [BackupCareEntry]
    var journal: [BackupJournalEntry]
}

nonisolated struct BackupCareEntry: Codable, Hashable, Identifiable {
    var id: UUID
    var kind: String
    var date: Date
    var note: String
}

nonisolated struct BackupJournalEntry: Codable, Hashable, Identifiable {
    var id: UUID
    var caption: String
    var date: Date
}

// MARK: - Export / import

enum DataExport {
    nonisolated static let fileName = "leafy-backup.json"

    // MARK: Encoding

    static func makeDocument(from plants: [Plant], exportedAt: Date = .now) -> BackupDocument {
        BackupDocument(
            exportedAt: exportedAt,
            plants: plants
                .sorted { $0.dateAdded < $1.dateAdded }
                .map { makeBackupPlant($0) }
        )
    }

    /// Pretty-printed with sorted keys: a backup people can open and read is a backup they trust.
    ///
    /// `nonisolated` because the share sheet encodes on a background thread — the document is a
    /// plain value by then, with no model objects left to touch.
    nonisolated static func encode(_ document: BackupDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(document)
    }

    nonisolated static func decode(_ data: Data) throws -> BackupDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(BackupDocument.self, from: data)
    }

    // MARK: Importing

    enum ImportError: LocalizedError {
        case unreadableFile
        case badFormat

        var errorDescription: String? {
            switch self {
            case .unreadableFile: "That file could not be opened."
            case .badFormat: "That does not look like a Leafy backup."
            }
        }
    }

    /// Adds every plant from a backup that is not in the store already.
    ///
    /// Merging by `id` and skipping matches keeps the operation safe to repeat: importing the
    /// same file twice adds nothing the second time, and a plant that has moved on since the
    /// backup was taken is never rolled back to its older self.
    @discardableResult
    static func merge(_ document: BackupDocument, into context: ModelContext) throws -> Int {
        let existing = Set((try? context.fetch(FetchDescriptor<Plant>()))?.map(\.id) ?? [])
        var imported = 0

        for backup in document.plants where !existing.contains(backup.id) {
            context.insert(makePlant(from: backup))
            imported += 1
        }

        if imported > 0 { try context.save() }
        return imported
    }

    /// Reads a file picked with `.fileImporter`, which hands back a security-scoped URL.
    static func readBackup(at url: URL) throws -> BackupDocument {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url) else { throw ImportError.unreadableFile }
        guard let document = try? decode(data) else { throw ImportError.badFormat }
        return document
    }

    // MARK: Mapping

    private static func makeBackupPlant(_ plant: Plant) -> BackupPlant {
        BackupPlant(
            id: plant.id,
            name: plant.name,
            species: plant.species,
            room: plant.room,
            notes: plant.notes,
            dateAdded: plant.dateAdded,
            remindersEnabled: plant.remindersEnabled,
            wateringIntervalDays: plant.wateringIntervalDays,
            fertilizingIntervalDays: plant.fertilizingIntervalDays,
            repottingIntervalDays: plant.repottingIntervalDays,
            lastWatered: plant.lastWatered,
            lastFertilized: plant.lastFertilized,
            lastRepotted: plant.lastRepotted,
            careLog: plant.careLog
                .sorted { $0.date < $1.date }
                .map { BackupCareEntry(id: $0.id, kind: $0.kindRawValue, date: $0.date, note: $0.note) },
            journal: plant.journal
                .sorted { $0.date < $1.date }
                .map { BackupJournalEntry(id: $0.id, caption: $0.caption, date: $0.date) }
        )
    }

    /// Journal entries are not restored: without their photo there would be nothing to show,
    /// so the captions in the file stay a record for the reader rather than data to import.
    private static func makePlant(from backup: BackupPlant) -> Plant {
        let plant = Plant(
            name: backup.name,
            species: backup.species,
            room: backup.room,
            notes: backup.notes,
            remindersEnabled: backup.remindersEnabled,
            wateringIntervalDays: backup.wateringIntervalDays,
            fertilizingIntervalDays: backup.fertilizingIntervalDays,
            repottingIntervalDays: backup.repottingIntervalDays,
            dateAdded: backup.dateAdded
        )
        plant.id = backup.id
        plant.lastWatered = backup.lastWatered
        plant.lastFertilized = backup.lastFertilized
        plant.lastRepotted = backup.lastRepotted

        for entry in backup.careLog {
            let kind = CareKind(rawValue: entry.kind) ?? .watering
            let log = CareLogEntry(kind: kind, date: entry.date, note: entry.note)
            log.id = entry.id
            log.plant = plant
            plant.careLog.append(log)
        }

        return plant
    }
}

// MARK: - Shareable file

/// Wraps the backup so `ShareLink` can hand the system a real `.json` file with a sensible
/// name, rather than a wall of text in the share sheet.
///
/// It holds the snapshot, not the encoded bytes: a `ShareLink` item is rebuilt every time its
/// view's `body` runs, and re-serialising the whole garden on each pass would be wasted work.
/// The JSON is written when the share sheet actually asks for the file — and a failure there
/// throws, so the sheet reports it instead of quietly handing over a broken file.
struct BackupFile: Transferable, Sendable {
    let document: BackupDocument

    init(plants: [Plant]) {
        self.document = DataExport.makeDocument(from: plants)
    }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { file in
            let data = try DataExport.encode(file.document)
            let url = FileManager.default.temporaryDirectory.appending(path: DataExport.fileName)
            try? FileManager.default.removeItem(at: url)
            try data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
        .suggestedFileName(DataExport.fileName)
    }
}

// MARK: - Care sheet

/// A plant's schedule as plain text, for sharing with whoever is watering while you are away.
enum PlantCareSheet {
    static func text(for plant: Plant, on date: Date = .now, calendar: Calendar = .current) -> String {
        var lines: [String] = []

        lines.append("\(plant.name) — care sheet")
        lines.append(plant.displaySpecies)
        lines.append("Room: \(plant.room)")
        lines.append("")
        lines.append("Schedule")

        for kind in CareKind.allCases {
            let cadence = "every \(Format.days(plant.interval(for: kind)))"
            let status = plant.statusText(for: kind, from: date, calendar: calendar).lowercased()
            let last = plant.lastCareDate(for: kind).map {
                ", last \($0.formatted(.dateTime.day().month(.abbreviated).year()))"
            } ?? ", not logged yet"

            lines.append("• \(kind.title): \(cadence) — \(status)\(last)")
        }

        if !plant.notes.isEmpty {
            lines.append("")
            lines.append("Notes")
            lines.append(plant.notes)
        }

        let recent = plant.careLog.sorted { $0.date > $1.date }.prefix(5)
        if !recent.isEmpty {
            lines.append("")
            lines.append("Recently")
            for entry in recent {
                lines.append("• \(entry.kind.completedTitle) \(entry.date.formatted(.dateTime.day().month(.abbreviated)))")
            }
        }

        lines.append("")
        lines.append("Shared from Leafy 🌿")

        return lines.joined(separator: "\n")
    }
}
