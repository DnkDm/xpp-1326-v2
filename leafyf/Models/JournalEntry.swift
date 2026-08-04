import Foundation
import SwiftData

/// A dated photo with an optional note — the plant's growth diary.
@Model
final class JournalEntry {
    @Attribute(.unique) var id: UUID
    @Attribute(.externalStorage) var photoData: Data
    var thumbnailData: Data?
    var date: Date
    var caption: String
    var plant: Plant?

    init(photo: ProcessedPhoto, caption: String = "", date: Date = .now) {
        self.id = UUID()
        self.photoData = photo.full
        self.thumbnailData = photo.thumbnail
        self.caption = caption
        self.date = date
    }
}
