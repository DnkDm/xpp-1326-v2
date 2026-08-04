import ImageIO
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

/// A picked photo, stored at two sizes: one for detail screens and a small one for lists.
struct ProcessedPhoto: Sendable, Equatable {
    let full: Data
    let thumbnail: Data
}

enum PhotoLibrary {
    /// Loads a picked item and downsamples it, so a 12-megapixel original never reaches the store.
    static func process(_ item: PhotosPickerItem) async -> ProcessedPhoto? {
        guard let data = try? await item.loadTransferable(type: Data.self) else { return nil }

        return await Task.detached(priority: .userInitiated) {
            guard let full = downsampledJPEG(from: data, maxPixelSize: 1400) else { return nil }
            let thumbnail = downsampledJPEG(from: data, maxPixelSize: 320, quality: 0.7) ?? full
            return ProcessedPhoto(full: full, thumbnail: thumbnail)
        }.value
    }

    nonisolated private static func downsampledJPEG(
        from data: Data,
        maxPixelSize: Int,
        quality: Double = 0.82
    ) -> Data? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }

        let thumbnailOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary

        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions) else { return nil }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }

        return output as Data
    }
}
