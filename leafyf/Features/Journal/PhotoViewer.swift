import SwiftUI
import UIKit

/// A journal photo on its own, full screen and zoomable.
///
/// Presented as a `fullScreenCover`: a growth photo is the whole point of the journal, and a
/// grid tile is too small to see a new leaf in. Pinch or double-tap to zoom, drag to pan once
/// zoomed, and flick down to dismiss while at normal size.
struct PhotoViewer: View {
    let entry: JournalEntry

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var pinch: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var pan: CGSize = .zero
    @State private var dismissDrag: CGFloat = 0
    @State private var showsChrome = true

    private static let maxScale: CGFloat = 4

    private var isZoomed: Bool { scale > 1.01 }

    /// The backdrop thins out as the photo is dragged away, so the gesture feels like it is
    /// pulling the photo off the screen rather than sliding a sheet.
    private var backdropOpacity: Double {
        max(1 - abs(dismissDrag) / 420, 0.4)
    }

    var body: some View {
        ZStack {
            Color.black
                .opacity(backdropOpacity)
                .ignoresSafeArea()

            photo

            if showsChrome {
                chrome.transition(.opacity)
            }
        }
        .statusBarHidden()
        .onTapGesture { withAnimation(.snappy) { showsChrome.toggle() } }
    }

    // MARK: - Photo

    private var photo: some View {
        Group {
            if let image = UIImage(data: entry.photoData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 64))
                    .foregroundStyle(.white.opacity(0.4))
            }
        }
        .scaleEffect(scale * pinch)
        .offset(
            x: offset.width + pan.width,
            y: offset.height + pan.height + dismissDrag
        )
        .gesture(doubleTap)
        .simultaneousGesture(magnify)
        .simultaneousGesture(drag)
        .animation(.snappy(duration: 0.25), value: scale)
    }

    private var chrome: some View {
        VStack {
            HStack {
                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .accessibilityLabel("Close")
            }
            .padding(Metrics.screenPadding)

            Spacer()

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.plant?.name ?? "Removed plant")
                        .font(.subheadline.weight(.semibold))

                    Text(entry.date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                }

                if !entry.caption.isEmpty {
                    Text(entry.caption)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.screenPadding)
            .background(.ultraThinMaterial)
        }
    }

    // MARK: - Gestures

    private var magnify: some Gesture {
        MagnifyGesture()
            .onChanged { pinch = $0.magnification }
            .onEnded { value in
                pinch = 1
                setScale(scale * value.magnification)
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if isZoomed {
                    pan = value.translation
                } else {
                    dismissDrag = value.translation.height
                }
            }
            .onEnded { value in
                if isZoomed {
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                    pan = .zero
                } else if abs(value.translation.height) > 120 {
                    dismiss()
                } else {
                    withAnimation(.snappy) { dismissDrag = 0 }
                }
            }
    }

    private var doubleTap: some Gesture {
        TapGesture(count: 2).onEnded {
            withAnimation(.snappy) {
                setScale(isZoomed ? 1 : 2.5)
            }
        }
    }

    private func setScale(_ new: CGFloat) {
        scale = min(max(new, 1), Self.maxScale)
        if !isZoomed {
            offset = .zero
            pan = .zero
        }
    }
}

#Preview {
    PhotoViewer(entry: PreviewData.sampleJournalEntry)
}
