import SwiftUI

struct GameCanvasView: View {
    @ObservedObject var engine: GameEngine

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            ZStack {
                // Lane rails
                ForEach(0..<3, id: \.self) { i in
                    Capsule()
                        .fill(GameTheme.foam.opacity(engine.lane == i ? 0.14 : 0.05))
                        .frame(width: w * 0.22, height: h * 0.78)
                        .position(x: laneScreenX(i, width: w), y: h * 0.48)
                        .animation(.easeOut(duration: 0.2), value: engine.lane)
                }

                // Falling entities
                ForEach(engine.entities) { entity in
                    EntityView(kind: entity.kind)
                        .position(
                            x: laneScreenX(entity.lane, width: w),
                            y: entity.y * h
                        )
                        .transition(.opacity)
                }

                // Collect bursts
                ForEach(engine.bursts) { burst in
                    BurstView()
                        .position(x: burst.x * w, y: burst.y * h)
                }

                // Player spark
                PlayerSpark()
                    .position(
                        x: laneScreenX(engine.lane, width: w),
                        y: engine.playerY * h
                    )
                    .animation(.spring(response: 0.28, dampingFraction: 0.78), value: engine.lane)

                // HUD
                VStack {
                    HStack {
                        Text("\(engine.score)")
                            .font(.system(size: 36, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(GameTheme.foam)
                        Spacer()
                        Text("BEST \(engine.highScore)")
                            .font(.system(size: 13, weight: .semibold, design: .rounded).monospacedDigit())
                            .tracking(1)
                            .foregroundStyle(GameTheme.foam.opacity(0.5))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 18)

                    Spacer()
                }

                // Touch zones
                HStack(spacing: 0) {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { engine.moveLeft() }
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture { engine.moveRight() }
                }

                if engine.phase == .gameOver {
                    GameOverView(engine: engine)
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                }
            }
            .offset(x: engine.shake > 0 ? CGFloat.random(in: -6...6) * engine.shake : 0)
        }
        .ignoresSafeArea()
    }

    private func laneScreenX(_ lane: Int, width: CGFloat) -> CGFloat {
        width * CGFloat(lane + 1) / 4
    }
}

struct PlayerSpark: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .fill(GameTheme.spark)
                .frame(width: 78, height: 78)
                .blur(radius: 2)

            Circle()
                .stroke(GameTheme.foam.opacity(0.35), lineWidth: 2)
                .frame(width: 52, height: 52)
                .rotationEffect(.degrees(spin ? 360 : 0))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [Color.white, GameTheme.amber, GameTheme.coral],
                        center: .center,
                        startRadius: 1,
                        endRadius: 22
                    )
                )
                .frame(width: 40, height: 40)
                .shadow(color: GameTheme.coral.opacity(0.7), radius: 12)
        }
        .onAppear {
            withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

struct EntityView: View {
    let kind: EntityKind

    var body: some View {
        switch kind {
        case .orb:
            ZStack {
                Circle()
                    .fill(GameTheme.teal.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .blur(radius: 6)
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [GameTheme.foam, GameTheme.teal],
                            center: .center,
                            startRadius: 1,
                            endRadius: 16
                        )
                    )
                    .frame(width: 28, height: 28)
                    .shadow(color: GameTheme.teal.opacity(0.6), radius: 8)
            }
        case .hazard:
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(GameTheme.stone.opacity(0.9))
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .rotationEffect(.degrees(12))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 4)

                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(Color.white.opacity(0.35))
            }
        }
    }
}

struct BurstView: View {
    @State private var expand = false

    var body: some View {
        ZStack {
            ForEach(0..<6, id: \.self) { i in
                Circle()
                    .fill(i.isMultiple(of: 2) ? GameTheme.amber : GameTheme.teal)
                    .frame(width: 8, height: 8)
                    .offset(y: expand ? -28 : 0)
                    .rotationEffect(.degrees(Double(i) * 60))
                    .opacity(expand ? 0 : 1)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.45)) { expand = true }
        }
    }
}
