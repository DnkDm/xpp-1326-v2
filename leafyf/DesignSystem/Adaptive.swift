import SwiftUI
import UIKit

// MARK: - Device

enum Device {
    /// Fixed for the life of the process, so it is read once rather than per view update.
    static let isPad = UIDevice.current.userInterfaceIdiom == .pad
}

// MARK: - Size class

extension Optional where Wrapped == UserInterfaceSizeClass {
    /// True only on an iPad with room for the wide layout: full screen, or a wide split.
    ///
    /// The idiom is checked as well as the size class because a Max-sized iPhone in
    /// landscape also reports a regular width — and the phone design should be the same
    /// whichever way the phone is held. Slide Over and narrow iPad splits stay compact
    /// and fall back to the phone design too.
    var usesPadLayout: Bool {
        Device.isPad && self == .regular
    }
}

// MARK: - Metrics

extension Metrics {
    static let padScreenPadding: CGFloat = 28
    static let padSectionSpacing: CGFloat = 28
    static let padColumnSpacing: CGFloat = 24

    /// Card layouts stop growing past this so lines of text stay readable on a 13" iPad.
    static let padContentWidth: CGFloat = 1120

    /// Narrower cap for single-column reading surfaces such as Settings and onboarding.
    static let padReadingWidth: CGFloat = 680

    /// Side-by-side columns need real room. A regular width class alone does not promise
    /// it — an iPad sharing the screen two-thirds/one-third still counts as regular —
    /// so layouts that split horizontally check the measured width against this first.
    static let padTwoColumnWidth: CGFloat = 750

    static func padding(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass.usesPadLayout ? padScreenPadding : screenPadding
    }

    static func spacing(for sizeClass: UserInterfaceSizeClass?) -> CGFloat {
        sizeClass.usesPadLayout ? padSectionSpacing : sectionSpacing
    }
}

// MARK: - Width

/// Reports the width a full-screen view actually has to work with, for the layouts that
/// need more than the size class can tell them.
struct WidthReader<Content: View>: View {
    @ViewBuilder var content: (CGFloat) -> Content

    var body: some View {
        GeometryReader { proxy in
            content(proxy.size.width)
        }
    }
}

// MARK: - Grids

enum PadGrid {
    /// One adaptive column definition — the grid fits as many cards per row as the width allows.
    static func columns(minimum: CGFloat, spacing: CGFloat = 16) -> [GridItem] {
        [GridItem(.adaptive(minimum: minimum), spacing: spacing)]
    }

    /// Fixed-size tiles laid out left to right, used for photo grids.
    static func tiles(size: CGFloat, spacing: CGFloat = 10) -> [GridItem] {
        [GridItem(.adaptive(minimum: size, maximum: size), spacing: spacing)]
    }
}

// MARK: - Modifiers

extension View {
    /// Centres content and stops it stretching edge to edge on an iPad.
    /// A no-op when `enabled` is false, so the phone layout is untouched.
    @ViewBuilder
    func maxContentWidth(_ limit: CGFloat, enabled: Bool = true) -> some View {
        if enabled {
            frame(maxWidth: limit)
                .frame(maxWidth: .infinity)
        } else {
            self
        }
    }

    /// Trackpad and mouse feedback for iPadOS. Inert on touch-only devices.
    @ViewBuilder
    func pointerLift(_ enabled: Bool = true) -> some View {
        if enabled {
            hoverEffect(.lift)
        } else {
            self
        }
    }
}
