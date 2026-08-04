import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

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
            }
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

    static let all: [Page] = [
        Page(
            symbolName: "leaf.fill",
            tint: .leafGreen,
            title: "Every plant,\nin one place",
            subtitle: "Keep names, rooms and care schedules together instead of in your head."
        ),
        Page(
            symbolName: "drop.fill",
            tint: .leafWater,
            title: "Never miss\na watering",
            subtitle: "Leafy works out what is due and reminds you at a time you choose."
        ),
        Page(
            symbolName: "camera.fill",
            tint: .leafGold,
            title: "Watch them\ngrow",
            subtitle: "Add a photo now and then, and the journal turns it into a timeline."
        ),
    ]
}

private struct PageView: View {
    let page: Page

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            ZStack {
                Circle()
                    .fill(page.tint.opacity(0.14))
                    .frame(width: 200, height: 200)
                Image(systemName: page.symbolName)
                    .font(.system(size: 78))
                    .foregroundStyle(page.tint)
            }

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
