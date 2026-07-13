import SwiftUI

/// Random miniature scenes that stream from the charging socket.
enum ChargeScene: String, CaseIterable, Identifiable {
    case flower, rocket, drone, train, ferrari, scooter
    case fish, sparrows, snake, sunrise, popcorn, beach

    var id: String { rawValue }

    var title: String {
        switch self {
        case .flower: return "Flowers"
        case .rocket: return "Rocket"
        case .drone: return "Drone"
        case .train: return "Train"
        case .ferrari: return "Ferrari"
        case .scooter: return "Scooter"
        case .fish: return "Fish"
        case .sparrows: return "Sparrows"
        case .snake: return "Snake"
        case .sunrise: return "Sunrise"
        case .popcorn: return "Popcorn"
        case .beach: return "Sea beach"
        }
    }

    static func random(excluding current: ChargeScene? = nil) -> ChargeScene {
        var next = allCases.randomElement() ?? .flower
        if let current, allCases.count > 1 {
            while next == current { next = allCases.randomElement() ?? .flower }
        }
        return next
    }
}

struct ChargingFlowerField: View {
    let isActive: Bool
    let size: CGSize

    @State private var particles: [ChargeParticle] = []
    @State private var tick = 0
    @State private var scene: ChargeScene = .random()
    @State private var nextChange = Date().addingTimeInterval(4)

    private let colors: [Color] = [
        Color(red: 1.00, green: 0.45, blue: 0.62),
        Color(red: 1.00, green: 0.72, blue: 0.28),
        Color(red: 0.55, green: 0.85, blue: 1.00),
        Color(red: 0.72, green: 0.55, blue: 1.00),
        Color(red: 0.45, green: 0.92, blue: 0.70),
        Color(red: 1.00, green: 0.55, blue: 0.30),
        Color(red: 1.00, green: 0.85, blue: 0.40),
        Color(red: 0.95, green: 0.35, blue: 0.35),
        Color(red: 0.35, green: 0.75, blue: 1.00)
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 28, paused: !isActive)) { timeline in
            ZStack(alignment: .bottom) {
                Canvas { context, canvas in
                    let socket = CGPoint(x: canvas.width * 0.5, y: canvas.height - 8)
                    if isActive {
                        drawBackdrop(context: context, canvas: canvas, scene: scene)
                        drawSocket(context: context, socket: socket)
                    }
                    for p in particles {
                        let age = timeline.date.timeIntervalSince(p.born)
                        guard age >= 0, age < p.life else { continue }
                        let t = age / p.life
                        let pos = position(p, t: t, socket: socket, canvas: canvas)
                        let opacity = max(0, 1 - pow(t, 1.5))
                        let scale = p.scale * (0.4 + 0.6 * (1 - abs(t - 0.3)))
                        drawParticle(p, at: pos, t: t, scale: scale, opacity: opacity, context: context)
                    }
                }

                if isActive {
                    Text(scene.title.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(2)
                        .foregroundStyle(.white.opacity(0.55))
                        .padding(.bottom, 36)
                        .transition(.opacity)
                        .id(scene)
                }
            }
            .onChange(of: timeline.date) { _, date in
                guard isActive else { return }
                if date >= nextChange {
                    scene = .random(excluding: scene)
                    nextChange = date.addingTimeInterval(Double.random(in: 3.2...5.2))
                    spawn(Int.random(in: 10...18), at: date)
                }
                prune(date)
                tick += 1
                if tick % 2 == 0 { spawn(Int.random(in: 1...4), at: date) }
            }
        }
        .allowsHitTesting(false)
        .onChange(of: isActive) { _, on in
            if on {
                scene = .random()
                nextChange = Date().addingTimeInterval(4)
                spawn(14, at: Date())
            } else {
                particles.removeAll()
                tick = 0
            }
        }
        .onAppear {
            if isActive {
                scene = .random()
                spawn(14, at: Date())
            }
        }
        .animation(.easeInOut(duration: 0.35), value: scene)
    }

    private func drawBackdrop(context: GraphicsContext, canvas: CGSize, scene: ChargeScene) {
        switch scene {
        case .sunrise:
            let sunY = canvas.height * 0.42
            context.fill(
                Path(ellipseIn: CGRect(x: canvas.width * 0.5 - 40, y: sunY - 40, width: 80, height: 80)),
                with: .radialGradient(
                    Gradient(colors: [Color.orange.opacity(0.55), Color.yellow.opacity(0.15), .clear]),
                    center: CGPoint(x: canvas.width * 0.5, y: sunY),
                    startRadius: 4,
                    endRadius: 90
                )
            )
        case .beach:
            var sea = Path()
            sea.move(to: CGPoint(x: 0, y: canvas.height * 0.72))
            sea.addQuadCurve(
                to: CGPoint(x: canvas.width, y: canvas.height * 0.74),
                control: CGPoint(x: canvas.width * 0.5, y: canvas.height * 0.68)
            )
            sea.addLine(to: CGPoint(x: canvas.width, y: canvas.height))
            sea.addLine(to: CGPoint(x: 0, y: canvas.height))
            context.fill(sea, with: .color(Color(red: 0.2, green: 0.55, blue: 0.85).opacity(0.22)))
        default:
            break
        }
    }

    private func drawSocket(context: GraphicsContext, socket: CGPoint) {
        context.fill(
            Path(ellipseIn: CGRect(x: socket.x - 36, y: socket.y - 28, width: 72, height: 40)),
            with: .radialGradient(
                Gradient(colors: [Color(red: 1, green: 0.78, blue: 0.32).opacity(0.5), .clear]),
                center: socket, startRadius: 2, endRadius: 40
            )
        )
        context.fill(
            Path(roundedRect: CGRect(x: socket.x - 14, y: socket.y - 3, width: 28, height: 5), cornerSize: .init(width: 2, height: 2)),
            with: .color(.white.opacity(0.35))
        )
    }

    private func position(_ p: ChargeParticle, t: Double, socket: CGPoint, canvas: CGSize) -> CGPoint {
        let tt = CGFloat(t)
        switch p.scene {
        case .flower, .popcorn:
            let sway = sin(t * .pi * 2 * p.freq + p.phase) * p.amp
            return CGPoint(x: socket.x + p.drift * tt + sway, y: socket.y - tt * p.rise)
        case .rocket:
            return CGPoint(x: socket.x + sin(t * 6 + p.phase) * 10, y: socket.y - tt * p.rise * 1.15)
        case .drone:
            let hover = sin(t * .pi * 4 + p.phase) * 16
            return CGPoint(x: socket.x + p.drift * tt, y: socket.y - tt * p.rise * 0.85 + hover)
        case .train, .ferrari, .scooter:
            let dir: CGFloat = p.drift >= 0 ? 1 : -1
            let y = socket.y - 18 - sin(tt * .pi) * 12
            return CGPoint(x: socket.x + dir * abs(p.drift) * tt * 1.4, y: y - tt * 30)
        case .fish:
            let wave = sin(t * .pi * 3 + p.phase) * p.amp
            return CGPoint(x: socket.x + p.drift * tt, y: socket.y - tt * p.rise * 0.7 + wave)
        case .sparrows:
            let flap = sin(t * .pi * 8 + p.phase) * 10
            return CGPoint(x: socket.x + p.drift * tt, y: socket.y - tt * p.rise + flap)
        case .snake:
            let zig = sin(t * .pi * 5 + p.phase) * p.amp * 1.6
            return CGPoint(x: socket.x + zig, y: socket.y - tt * p.rise)
        case .sunrise:
            let arc = tt * .pi
            return CGPoint(
                x: socket.x + cos(arc + p.phase) * p.amp * 2.2,
                y: socket.y - sin(arc) * p.rise * 0.85
            )
        case .beach:
            let wave = sin(t * .pi * 2 + p.phase) * 14
            return CGPoint(x: socket.x + p.drift * tt, y: socket.y - 40 - tt * p.rise * 0.45 + wave)
        }
    }

    private func drawParticle(
        _ p: ChargeParticle,
        at point: CGPoint,
        t: Double,
        scale: CGFloat,
        opacity: Double,
        context: GraphicsContext
    ) {
        var context = context
        context.opacity = opacity
        let rot = p.spin * CGFloat(t) * .pi * 2
        var xform = CGAffineTransform.identity
            .translatedBy(x: point.x, y: point.y)
            .rotated(by: rot)
            .scaledBy(x: scale, y: scale)

        let path: Path
        switch p.scene {
        case .flower: path = blossom(petals: p.petals)
        case .rocket: path = rocket()
        case .drone: path = drone()
        case .train: path = train()
        case .ferrari: path = car()
        case .scooter: path = scooter()
        case .fish: path = fish()
        case .sparrows: path = bird()
        case .snake:
            context.stroke(
                snake().applying(xform),
                with: .color(p.color),
                style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round, lineJoin: .round)
            )
            return
        case .sunrise: path = sunburst()
        case .popcorn: path = popcorn()
        case .beach: path = shell()
        }
        context.fill(path.applying(xform), with: .color(p.color))
        if p.scene == .sunrise {
            context.stroke(
                sunburst().applying(xform),
                with: .color(p.color),
                lineWidth: 1.2
            )
        }
    }

    private func spawn(_ count: Int, at date: Date) {
        for _ in 0..<count {
            particles.append(
                ChargeParticle(
                    born: date,
                    life: Double.random(in: 2.0...4.0),
                    rise: CGFloat.random(in: size.height * 0.45...size.height * 0.95),
                    drift: CGFloat.random(in: -size.width * 0.42...size.width * 0.42),
                    amp: CGFloat.random(in: 10...32),
                    freq: Double.random(in: 0.6...2.2),
                    phase: Double.random(in: 0...(2 * .pi)),
                    spin: CGFloat.random(in: -1.8...1.8),
                    scale: CGFloat.random(in: 0.5...1.2),
                    color: colors.randomElement() ?? .pink,
                    scene: scene,
                    petals: [4, 5, 6].randomElement() ?? 5
                )
            )
        }
        if particles.count > 150 { particles.removeFirst(particles.count - 150) }
    }

    private func prune(_ now: Date) {
        particles.removeAll { now.timeIntervalSince($0.born) > $0.life }
    }

    // MARK: - Tiny shapes (~10–16pt)

    private func blossom(petals: Int) -> Path {
        var path = Path()
        for i in 0..<petals {
            let a = (CGFloat(i) / CGFloat(petals)) * .pi * 2 - .pi / 2
            path.addEllipse(in: CGRect(x: cos(a) * 5 - 2.2, y: sin(a) * 5 - 2.8, width: 4.4, height: 5.6))
        }
        return path
    }

    private func rocket() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -7))
        p.addLine(to: CGPoint(x: 4, y: 2))
        p.addLine(to: CGPoint(x: 2, y: 2))
        p.addLine(to: CGPoint(x: 3, y: 6))
        p.addLine(to: CGPoint(x: -3, y: 6))
        p.addLine(to: CGPoint(x: -2, y: 2))
        p.addLine(to: CGPoint(x: -4, y: 2))
        p.closeSubpath()
        return p
    }

    private func drone() -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: -3, y: -2, width: 6, height: 4))
        p.addEllipse(in: CGRect(x: -8, y: -5, width: 5, height: 5))
        p.addEllipse(in: CGRect(x: 3, y: -5, width: 5, height: 5))
        return p
    }

    private func train() -> Path {
        var p = Path()
        p.addRoundedRect(in: CGRect(x: -7, y: -3, width: 14, height: 7), cornerSize: .init(width: 1.5, height: 1.5))
        p.addEllipse(in: CGRect(x: -5, y: 3, width: 3, height: 3))
        p.addEllipse(in: CGRect(x: 2, y: 3, width: 3, height: 3))
        return p
    }

    private func car() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -8, y: 2))
        p.addLine(to: CGPoint(x: -6, y: -2))
        p.addLine(to: CGPoint(x: -2, y: -4))
        p.addLine(to: CGPoint(x: 3, y: -4))
        p.addLine(to: CGPoint(x: 7, y: -1))
        p.addLine(to: CGPoint(x: 8, y: 2))
        p.closeSubpath()
        p.addEllipse(in: CGRect(x: -5, y: 1, width: 3, height: 3))
        p.addEllipse(in: CGRect(x: 3, y: 1, width: 3, height: 3))
        return p
    }

    private func scooter() -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: -6, y: 2, width: 3.5, height: 3.5))
        p.addEllipse(in: CGRect(x: 3, y: 2, width: 3.5, height: 3.5))
        p.move(to: CGPoint(x: -4, y: 3))
        p.addLine(to: CGPoint(x: 4, y: 3))
        p.addLine(to: CGPoint(x: 5, y: -4))
        p.addLine(to: CGPoint(x: 3, y: -5))
        return p
    }

    private func fish() -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: -5, y: -2.5, width: 9, height: 5))
        p.move(to: CGPoint(x: 4, y: 0))
        p.addLine(to: CGPoint(x: 8, y: -3))
        p.addLine(to: CGPoint(x: 8, y: 3))
        p.closeSubpath()
        return p
    }

    private func bird() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -6, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0, y: -2), control: CGPoint(x: -3, y: -5))
        p.addQuadCurve(to: CGPoint(x: 6, y: 0), control: CGPoint(x: 3, y: -5))
        p.addQuadCurve(to: CGPoint(x: 0, y: 1), control: CGPoint(x: 2, y: 0))
        p.addQuadCurve(to: CGPoint(x: -6, y: 0), control: CGPoint(x: -2, y: 0))
        return p
    }

    private func snake() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: -7, y: 2))
        p.addCurve(to: CGPoint(x: -2, y: -2), control1: CGPoint(x: -5, y: -4), control2: CGPoint(x: -3, y: 4))
        p.addCurve(to: CGPoint(x: 4, y: 1), control1: CGPoint(x: 0, y: -6), control2: CGPoint(x: 2, y: 5))
        p.addCurve(to: CGPoint(x: 8, y: -2), control1: CGPoint(x: 6, y: -3), control2: CGPoint(x: 7, y: 2))
        return p
    }

    private func sunburst() -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: -3.5, y: -3.5, width: 7, height: 7))
        for i in 0..<8 {
            let a = CGFloat(i) / 8 * .pi * 2
            p.move(to: CGPoint(x: cos(a) * 4, y: sin(a) * 4))
            p.addLine(to: CGPoint(x: cos(a) * 7, y: sin(a) * 7))
        }
        return p
    }

    private func popcorn() -> Path {
        var p = Path()
        p.addEllipse(in: CGRect(x: -3, y: -4, width: 5, height: 5))
        p.addEllipse(in: CGRect(x: -1, y: -2, width: 5, height: 5))
        p.addEllipse(in: CGRect(x: -4, y: -1, width: 4.5, height: 4.5))
        return p
    }

    private func shell() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: -5))
        p.addQuadCurve(to: CGPoint(x: 6, y: 3), control: CGPoint(x: 6, y: -3))
        p.addQuadCurve(to: CGPoint(x: -6, y: 3), control: CGPoint(x: 0, y: 6))
        p.addQuadCurve(to: CGPoint(x: 0, y: -5), control: CGPoint(x: -6, y: -3))
        return p
    }
}

private struct ChargeParticle: Identifiable {
    let id = UUID()
    let born: Date
    let life: Double
    let rise: CGFloat
    let drift: CGFloat
    let amp: CGFloat
    let freq: Double
    let phase: Double
    let spin: CGFloat
    let scale: CGFloat
    let color: Color
    let scene: ChargeScene
    let petals: Int
}
