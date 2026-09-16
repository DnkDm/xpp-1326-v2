import SwiftUI

// MARK: - Celebration

/// A short burst of falling leaves and petals, for the moment the last task of the day is done.
///
/// Drawn in a single `Canvas` rather than as a stack of animated views: one layer, no view
/// identity churn, and nothing left running afterwards — the `TimelineView` is torn down as
/// soon as the burst ends, so an idle screen costs nothing.
///
/// Drop it in as an overlay and let it clean itself up:
/// ```
/// .overlay {
///     if isCelebrating {
///         CelebrationView { isCelebrating = false }
///             .allowsHitTesting(false)
///     }
/// }
/// ```
struct CelebrationView: View {
    var duration: Double = 2
    var origin: UnitPoint = .init(x: 0.5, y: 0.34)
    var onFinish: (() -> Void)?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var particles: [Particle] = []
    @State private var start = Date.now
    @State private var isFinished = false

    var body: some View {
        Group {
            if isFinished || reduceMotion {
                // Reduced motion gets the same news without anything flying across the screen.
                Color.clear
            } else {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let elapsed = timeline.date.timeIntervalSince(start)
                        draw(particles, in: &context, size: size, elapsed: elapsed)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        .task {
            particles = Particle.burst()
            start = .now

            try? await Task.sleep(for: .seconds(reduceMotion ? 0.1 : duration))
            isFinished = true
            onFinish?()
        }
    }

    // MARK: - Drawing

    private func draw(_ particles: [Particle], in context: inout GraphicsContext, size: CGSize, elapsed: Double) {
        let anchor = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
        let scale = min(size.width, size.height)

        for particle in particles {
            let time = elapsed - particle.delay
            guard time > 0 else { continue }

            // Plain projectile motion: thrown outwards, pulled down, slowed sideways.
            let x = anchor.x + particle.velocity.dx * scale * time
            let y = anchor.y + particle.velocity.dy * scale * time + 0.62 * scale * time * time
            guard y < size.height + 40 else { continue }

            let life = min(time / max(duration - particle.delay, 0.01), 1)
            let opacity = life < 0.75 ? 1 : (1 - (life - 0.75) / 0.25)
            let side = particle.size * scale

            context.drawLayer { layer in
                layer.translateBy(x: x, y: y)
                layer.rotate(by: .degrees(particle.spin * time * 360))
                layer.opacity = opacity
                layer.fill(
                    particle.shape.path(side: side),
                    with: .color(particle.color)
                )
            }
        }
    }
}

// MARK: - Particle

private struct Particle {
    enum Shape {
        case leaf
        case petal

        /// Centred on the origin so the layer transform can spin it around its middle.
        func path(side: CGFloat) -> Path {
            let rect = CGRect(x: -side / 2, y: -side / 2, width: side, height: side)
            switch self {
            case .leaf:
                var path = Path()
                path.move(to: CGPoint(x: rect.minX, y: rect.midY))
                path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.minY))
                path.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.midY), control: CGPoint(x: rect.midX, y: rect.maxY))
                return path
            case .petal:
                return Path(ellipseIn: rect.insetBy(dx: side * 0.16, dy: 0))
            }
        }
    }

    let velocity: CGVector
    let size: CGFloat
    let spin: Double
    let delay: Double
    let color: Color
    let shape: Shape

    /// Fanned upwards and outwards so the burst reads as thrown rather than sprayed.
    static func burst(count: Int = 46) -> [Particle] {
        let palette: [Color] = [.leafGreen, .leafMint, .leafGold, .leafClay, .leafWater]

        return (0..<count).map { index in
            let spread = Double.random(in: -1.05...1.05)
            let lift = Double.random(in: 0.55...1.25)

            return Particle(
                velocity: CGVector(dx: spread, dy: -lift),
                size: .random(in: 0.018...0.042),
                spin: .random(in: -0.9...0.9),
                delay: Double(index) * 0.006,
                color: palette[index % palette.count],
                shape: index.isMultiple(of: 3) ? .petal : .leaf
            )
        }
    }
}

#Preview {
    ZStack {
        Color.canvas.ignoresSafeArea()

        VStack(spacing: 8) {
            Text("🌿")
                .font(.system(size: 64))
            Text("All caught up")
                .font(.title2.bold())
                .foregroundStyle(.textPrimary)
        }
    }
    .overlay { CelebrationView().allowsHitTesting(false) }
}
