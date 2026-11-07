import SwiftUI

/// How much confetti to throw.
enum ConfettiStyle {
    /// The moment a game is won.
    case full
    /// Reopening a finished game.
    case quick
    /// A tie: a lighter sprinkle.
    case gentle

    fileprivate var count: Int {
        switch self {
        case .full: 140
        case .quick: 60
        case .gentle: 45
        }
    }

    fileprivate var duration: Double {
        switch self {
        case .full: 3.6
        case .quick: 2.0
        case .gentle: 3.0
        }
    }

    fileprivate var maxDelay: Double {
        switch self {
        case .full: 0.7
        case .quick: 0.25
        case .gentle: 0.9
        }
    }
}

private struct ConfettiParticle {
    let x: CGFloat
    let startY: CGFloat
    let vx: CGFloat
    let vy: CGFloat
    let delay: CGFloat
    let lifetime: CGFloat
    let spin: CGFloat
    let flip: CGFloat
    let wobble: CGFloat
    let phase: CGFloat
    let size: CGSize
    let isRound: Bool
    let color: Color

    static func burst(_ style: ConfettiStyle) -> [ConfettiParticle] {
        let colors: [Color] = [
            QTheme.sage,
            QTheme.gold,
            QTheme.sage.opacity(0.7),
            QTheme.gold.opacity(0.75),
            Color(red: 0.95, green: 0.91, blue: 0.82)
        ]
        return (0..<style.count).map { _ in
            let delay = CGFloat.random(in: 0...CGFloat(style.maxDelay))
            return ConfettiParticle(
                x: .random(in: 0.04...0.96),
                startY: .random(in: -40 ... -8),
                vx: .random(in: -70...70),
                vy: .random(in: 60...260),
                delay: delay,
                lifetime: CGFloat(style.duration) - delay,
                spin: .random(in: -6...6),
                flip: .random(in: 4...11),
                wobble: .random(in: 6...22),
                phase: .random(in: 0...(2 * .pi)),
                size: CGSize(width: .random(in: 6...10), height: .random(in: 9...15)),
                isRound: Int.random(in: 0..<5) == 0,
                color: colors.randomElement() ?? QTheme.gold
            )
        }
    }
}

/// Falling sage-and-gold confetti drawn with Canvas. It stops drawing when done.
struct ConfettiView: View {
    let style: ConfettiStyle
    @State private var particles: [ConfettiParticle] = []
    @State private var startDate: Date?
    @State private var isFinished = false

    private let gravity: CGFloat = 300

    var body: some View {
        TimelineView(.animation(paused: isFinished || startDate == nil)) { timeline in
            Canvas { context, size in
                guard let startDate else { return }
                let elapsed = CGFloat(timeline.date.timeIntervalSince(startDate))

                for particle in particles {
                    let t = elapsed - particle.delay
                    guard t > 0, t < particle.lifetime else { continue }

                    let x = particle.x * size.width + particle.vx * t + sin(t * 3 + particle.phase) * particle.wobble
                    let y = particle.startY + particle.vy * t + 0.5 * gravity * t * t
                    guard y < size.height + 30 else { continue }

                    var piece = context
                    piece.opacity = Double(min(1, (particle.lifetime - t) / 0.6))
                    piece.translateBy(x: x, y: y)
                    piece.rotate(by: .radians(Double(particle.spin * t + particle.phase)))
                    piece.scaleBy(x: cos(t * particle.flip), y: 1)

                    let rect = CGRect(
                        x: -particle.size.width / 2,
                        y: -particle.size.height / 2,
                        width: particle.size.width,
                        height: particle.size.height
                    )
                    let shape = particle.isRound
                        ? Path(ellipseIn: rect.insetBy(dx: 0, dy: (rect.height - rect.width) / 2))
                        : Path(roundedRect: rect, cornerRadius: 1.5)
                    piece.fill(shape, with: .color(particle.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task {
            guard startDate == nil else { return }
            particles = ConfettiParticle.burst(style)
            startDate = .now
            try? await Task.sleep(for: .seconds(style.duration))
            isFinished = true
        }
    }
}
