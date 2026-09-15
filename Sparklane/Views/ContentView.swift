import SwiftUI

struct ContentView: View {
    @StateObject private var engine = GameEngine()

    var body: some View {
        ZStack {
            GameTheme.sky.ignoresSafeArea()

            AtmosphereBackdrop(pulse: engine.pulse)

            switch engine.phase {
            case .menu:
                MenuView(engine: engine)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .playing, .gameOver:
                GameCanvasView(engine: engine)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: engine.phase)
    }
}

struct AtmosphereBackdrop: View {
    var pulse: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Soft horizon wash
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [
                                GameTheme.teal.opacity(pulse ? 0.28 : 0.16),
                                GameTheme.teal.opacity(0)
                            ],
                            center: .center,
                            startRadius: 20,
                            endRadius: geo.size.width * 0.7
                        )
                    )
                    .frame(width: geo.size.width * 1.4, height: geo.size.height * 0.55)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.18)
                    .blur(radius: 40)
                    .animation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true), value: pulse)

                // Warm ground glow near player
                Ellipse()
                    .fill(GameTheme.coral.opacity(0.12))
                    .frame(width: geo.size.width * 0.9, height: 160)
                    .blur(radius: 50)
                    .position(x: geo.size.width * 0.5, y: geo.size.height * 0.88)

                // Subtle lane light streaks
                ForEach(0..<3, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(GameTheme.foam.opacity(0.04))
                        .frame(width: geo.size.width * 0.18, height: geo.size.height)
                        .position(
                            x: geo.size.width * CGFloat(i + 1) / 4,
                            y: geo.size.height * 0.5
                        )
                }
            }
        }
        .allowsHitTesting(false)
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
}
