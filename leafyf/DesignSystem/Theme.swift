import SwiftUI
import UIKit

// MARK: - Palette

/// Declared on `ShapeStyle` so the colours work both as `Color.canvas` and as the
/// shorthand `.foregroundStyle(.textPrimary)`.
extension ShapeStyle where Self == Color {
    // Brand colours, identical in both appearances.
    static var leafGreen: Color { Color(hex: 0x4F8F5B) }
    static var leafMint: Color { Color(hex: 0x7DB87A) }
    static var leafGold: Color { Color(hex: 0xD09A45) }
    static var leafClay: Color { Color(hex: 0xC4685E) }
    static var leafWater: Color { Color(hex: 0x4A9BC4) }

    // Semantic colours that follow Light garden ↔ Dark greenhouse.
    static var canvas: Color { .adaptive(light: 0xF1F6F0, dark: 0x121A13) }
    static var surface: Color { .adaptive(light: 0xFFFFFF, dark: 0x1C251D) }
    static var surfaceMuted: Color { .adaptive(light: 0xF6EFE0, dark: 0x252014) }
    static var hairline: Color { .adaptive(light: 0xE1EAE0, dark: 0x2E3B2F) }
    static var textPrimary: Color { .adaptive(light: 0x1F2D22, dark: 0xE9F1E7) }
    static var textSecondary: Color { .adaptive(light: 0x5D7062, dark: 0x9BAE9C) }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }

    fileprivate static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

// MARK: - Metrics

enum Metrics {
    static let corner: CGFloat = 18
    static let smallCorner: CGFloat = 12
    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 22
}

// MARK: - Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    var background: Color

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background, in: RoundedRectangle(cornerRadius: Metrics.corner, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

extension View {
    func card(padding: CGFloat = Metrics.cardPadding, background: Color = .surface) -> some View {
        modifier(CardModifier(padding: padding, background: background))
    }

    /// Fills the screen with the app canvas and hides the default grouped background.
    func canvasBackground() -> some View {
        scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
    }
}
