import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var page = 0

    private let pages = Page.all

    var body: some View {
        ZStack {
            Color.canvas.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $page) {
                    ForEach(Array(pages.enumerated()), id: \.element.id) { index, page in
                        PageView(page: page)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                VStack(spacing: 20) {
                    PageIndicator(count: pages.count, current: page)

                    Button(page == pages.count - 1 ? "Get started" : "Continue") {
                        withAnimation(.snappy) {
                            if page < pages.count - 1 {
                                page += 1
                            } else {
                                onFinish()
                            }
                        }
                    }
                    .buttonStyle(.primary)

                    Button("Skip", action: onFinish)
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                        .opacity(page == pages.count - 1 ? 0 : 1)
                        .disabled(page == pages.count - 1)
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 40)
                .maxContentWidth(480, enabled: sizeClass.usesPadLayout)
            }
            // Onboarding is a single stream of text and one button; on an iPad it reads
            // as a centred column rather than three words stranded across the screen.
            .maxContentWidth(660, enabled: sizeClass.usesPadLayout)
        }
    }
}

// MARK: - Page

private struct Page: Identifiable {
    let id = UUID()
    let symbolName: String
    let tint: Color
    let title: String
    let subtitle: String
    /// Small symbols pinned around the main one, so each page has an illustration rather
    /// than one glyph in a circle. Positions are fractions of the circle's radius.
    var accents: [Accent] = []

    struct Accent: Identifiable {
        let id = UUID()
        let symbolName: String
        let tint: Color
        let x: CGFloat
        let y: CGFloat
    }

    static let all: [Page] = [
        Page(
            symbolName: "leaf.fill",
            tint: .leafGreen,
            title: "Every plant,\nin one place",
            subtitle: "Keep names, rooms and care schedules together instead of in your head.",
            accents: [
                Accent(symbolName: "house.fill", tint: .leafMint, x: -0.78, y: -0.55),
                Accent(symbolName: "sparkles", tint: .leafGold, x: 0.74, y: 0.58),
            ]
        ),
        Page(
            symbolName: "drop.fill",
            tint: .leafWater,
            title: "Never miss\na watering",
            subtitle: "Leafy works out what is due and reminds you at a time you choose.",
            accents: [
                Accent(symbolName: "bell.badge.fill", tint: .leafGold, x: 0.78, y: -0.52),
                Accent(symbolName: "calendar", tint: .leafGreen, x: -0.76, y: 0.56),
            ]
        ),
        Page(
            symbolName: "camera.fill",
            tint: .leafGold,
            title: "Watch them\ngrow",
            subtitle: "Add a photo now and then, and the journal turns it into a timeline.",
            accents: [
                Accent(symbolName: "photo.stack.fill", tint: .leafGreen, x: -0.8, y: -0.5),
                Accent(symbolName: "chart.bar.fill", tint: .leafClay, x: 0.76, y: 0.55),
            ]
        ),
        Page(
            symbolName: "globe.europe.africa.fill",
            tint: .leafMint,
            title: "Explore, and\ncheck the sky",
            subtitle: "Look up any species from inside the app, and let today's weather nudge your care — a mist in dry air, a drink sooner in a heatwave.",
            accents: [
                Accent(symbolName: "cloud.sun.fill", tint: .leafWater, x: 0.8, y: -0.5),
                Accent(symbolName: "magnifyingglass", tint: .leafGreen, x: -0.76, y: 0.55),
            ]
        ),
    ]
}

private struct PageView: View {
    let page: Page

    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hasAppeared = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            artwork

            VStack(spacing: 12) {
                Text(page.title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.textPrimary)
                Text(page.subtitle)
                    .font(.body)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, 32)
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .onAppear { withAnimation(.snappy(duration: 0.45)) { hasAppeared = true } }
    }

    /// The main symbol in its tinted circle, with two smaller ones settling in around it.
    private var artwork: some View {
        ZStack {
            Circle()
                .fill(page.tint.opacity(0.14))
                .frame(width: artSize, height: artSize)

            Image(systemName: page.symbolName)
                .font(.system(size: artSize * 0.39))
                .foregroundStyle(page.tint)

            ForEach(page.accents) { accent in
                Image(systemName: accent.symbolName)
                    .font(.system(size: artSize * 0.14))
                    .foregroundStyle(accent.tint)
                    .padding(artSize * 0.075)
                    .background(Color.surface, in: Circle())
                    .shadow(color: .black.opacity(0.07), radius: 6, y: 2)
                    .offset(x: accent.x * artSize / 2, y: accent.y * artSize / 2)
                    .scaleEffect(scale)
                    .opacity(hasAppeared ? 1 : 0)
            }
        }
        .frame(width: artSize, height: artSize)
        .accessibilityHidden(true)
    }

    private var scale: CGFloat {
        reduceMotion || hasAppeared ? 1 : 0.6
    }

    private var artSize: CGFloat {
        sizeClass.usesPadLayout ? 260 : 200
    }
}

private struct PageIndicator: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(index == current ? Color.leafGreen : Color.leafGreen.opacity(0.22))
                    .frame(width: index == current ? 22 : 8, height: 8)
            }
        }
        .animation(.snappy, value: current)
        .accessibilityHidden(true)
    }
}

#Preview {
    OnboardingView {}
}
