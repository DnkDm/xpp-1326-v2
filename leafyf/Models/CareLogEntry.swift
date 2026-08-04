import Foundation
import SwiftData

/// One completed care action, kept so the calendar and detail screen can show real history.
@Model
final class CareLogEntry {
    @Attribute(.unique) var id: UUID
    var kindRawValue: String
    var date: Date
    var note: String
    var plant: Plant?

    init(kind: CareKind, date: Date = .now, note: String = "") {
        self.id = UUID()
        self.kindRawValue = kind.rawValue
        self.date = date
        self.note = note
    }

    var kind: CareKind {
        CareKind(rawValue: kindRawValue) ?? .watering
    }
}
