import SwiftUI

/// Tiny colorful flowers that pour into the screen from the bottom charging socket.
struct ChargingFlowerField: View {
    let isActive: Bool
    let size: CGSize

    @State private var flowers: [FlyingFlower] = []
    @State private var tick: Int = 0

    private let palette: [Color] = [
        Color(red: 1.00, green: 0.45, blue: 0.62), // rose
        Color(red: 1.00, green: 0.72, blue: 0.28), // marigold
        Color(red: 0.55, green: 0.85, blue: 1.00), // sky
        Color(red: 0.72, green: 0.55, blue: 1.00), // lilac
        Color(red: 0.45, green: 0.92, blue: 0.70), // mint
        Color(red: 1.00, green: 0.55, blue: 0.30), // coral
        Color(red: 1.00, green: 0.85, blue: 0.40)  // butter
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isActive)) { timeline in
            Canvas { context, canvasSize in
                let socket = CGPoint(x: canvasSize.width * 0.5, y: canvasSize.height - 8)

                // Soft glow at the USB-C socket
                if isActive {
                    let glowRect = CGRect(x: socket.x - 36, y: socket.y - 28, width: 72, height: 40)
                    context.fill(
                        Path(ellipseIn: glowRect),
                        with: .radialGradient(
                            Gradient(colors: [
                                Color(red: 1.0, green: 0.78, blue: 0.32).opacity(0.55),
                                .clear
                            ]),
                            center: socket,
                            startRadius: 2,
                            endRadius: 40
                        )
                    )

                    // Tiny port silhouette
                    var port = Path(roundedRect: CGRect(x: socket.x - 14, y: socket.y - 3, width: 28, height: 5), cornerSize: CGSize(width: 2, height: 2))
                    context.fill(port, with: .color(.white.opacity(0.35)))
                }

                for flower in flowers {
                    let age = timeline.date.timeIntervalSince(flower.born)
                    guard age >= 0, age < flower.lifetime else { continue }

                    let t = age / flower.lifetime
                    let y = socket.y - CGFloat(t) * flower.rise
                    let sway = sin((t * .pi * 2 * flower.swayFreq) + flower.phase) * flower.swayAmp
                    let x = socket.x + flower.drift * CGFloat(t) + sway
                    let scale = flower.scale * (0.35 + 0.65 * (1 - abs(t - 0.35)))
                    let opacity = Double(1 - pow(t, 1.6))

                    var transform = CGAffineTransform.identity
                        .translatedBy(x: x, y: y)
                        .rotated(by: flower.spin * CGFloat(t) * .pi * 2)
                        .scaledBy(x: scale, y: scale)

                    let petal = flowerPath().applying(transform)
                    context.opacity = opacity
                    context.fill(petal, with: .color(flower.color))
                    // Center speck
                    let center = Path(ellipseIn: CGRect(x: x - 1.4 * scale, y: y - 1.4 * scale, width: 2.8 * scale, height: 2.8 * scale))
                    context.fill(center, with: .color(Color(red: 1.0, green: 0.92, blue: 0.45).opacity(opacity)))
                }
            }
            .onChange(of: timeline.date) { _, date in
                guard isActive else { return }
                prune(now: date)
                // Spawn a few small flowers from the socket each frame burst
                tick += 1
                if tick % 2 == 0 {
                    spawn(count: Int.random(in: 1...3), at: date)
                }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, active in
            if !active {
                flowers.removeAll()
                tick = 0
            } else {
                spawn(count: 10, at: Date())
            }
        }
        .onAppear {
            if isActive { spawn(count: 12, at: Date()) }
        }
    }

    private func spawn(count: Int, at date: Date) {
        for _ in 0..<count {
            flowers.append(
                FlyingFlower(
                    born: date,
                    lifetime: Double.random(in: 2.2...4.0),
                    rise: CGFloat.random(in: size.height * 0.55...size.height * 0.92),
                    drift: CGFloat.random(in: -size.width * 0.38...size.width * 0.38),
                    swayAmp: CGFloat.random(in: 8...28),
                    swayFreq: Double.random(in: 0.8...1.8),
                    phase: Double.random(in: 0...(2 * .pi)),
                    spin: CGFloat.random(in: -1.4...1.4),
                    scale: CGFloat.random(in: 0.55...1.15),
                    color: palette.randomElement() ?? .pink
                )
            )
        }
        if flowers.count > 120 {
            flowers.removeFirst(flowers.count - 120)
        }
    }

    private func prune(now: Date) {
        flowers.removeAll { now.timeIntervalSince($0.born) > $0.lifetime }
    }

    /// Simple 5-petal blossom drawn around origin (~10pt wide).
    private func flowerPath() -> Path {
        var path = Path()
        let petals = 5
        let petalRadius: CGFloat = 4.2
        let reach: CGFloat = 5.5
        for i in 0..<petals {
            let angle = (CGFloat(i) / CGFloat(petals)) * .pi * 2 - .pi / 2
            let cx = cos(angle) * reach
            let cy = sin(angle) * reach
            path.addEllipse(in: CGRect(x: cx - petalRadius * 0.55, y: cy - petalRadius * 0.7, width: petalRadius * 1.1, height: petalRadius * 1.4))
        }
        return path
    }
}

private struct FlyingFlower: Identifiable {
    let id = UUID()
    let born: Date
    let lifetime: Double
    let rise: CGFloat
    let drift: CGFloat
    let swayAmp: CGFloat
    let swayFreq: Double
    let phase: Double
    let spin: CGFloat
    let scale: CGFloat
    let color: Color
}
