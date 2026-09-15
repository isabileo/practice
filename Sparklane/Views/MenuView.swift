import SwiftUI

struct MenuView: View {
    @ObservedObject var engine: GameEngine
    @State private var intro = false
    @State private var orbBob = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 56)

            ZStack {
                Circle()
                    .fill(GameTheme.spark)
                    .frame(width: 120, height: 120)
                    .blur(radius: 8)
                    .offset(y: orbBob ? -8 : 8)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [GameTheme.amber, GameTheme.coral],
                            center: .center,
                            startRadius: 2,
                            endRadius: 36
                        )
                    )
                    .frame(width: 64, height: 64)
                    .shadow(color: GameTheme.coral.opacity(0.55), radius: 18, y: 6)
                    .offset(y: orbBob ? -8 : 8)
            }
            .padding(.bottom, 36)
            .opacity(intro ? 1 : 0)
            .offset(y: intro ? 0 : 16)

            Text("SPARKLANE")
                .font(.system(size: 44, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundStyle(
                    LinearGradient(
                        colors: [GameTheme.foam, GameTheme.teal],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .opacity(intro ? 1 : 0)
                .offset(y: intro ? 0 : 12)

            Text("Dodge the void. Collect the charge.")
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(GameTheme.foam.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.top, 14)
                .padding(.horizontal, 36)
                .opacity(intro ? 1 : 0)

            Spacer()

            if engine.highScore > 0 {
                Text("BEST  \(engine.highScore)")
                    .font(.system(size: 14, weight: .semibold, design: .rounded).monospacedDigit())
                    .tracking(2)
                    .foregroundStyle(GameTheme.amber.opacity(0.9))
                    .padding(.bottom, 20)
            }

            Button(action: engine.start) {
                Text("PLAY")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .tracking(3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        LinearGradient(
                            colors: [GameTheme.coral, GameTheme.amber],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(Color(red: 0.08, green: 0.06, blue: 0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .shadow(color: GameTheme.coral.opacity(0.35), radius: 16, y: 8)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 18)

            Text("Tap left or right to switch lanes")
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(GameTheme.foam.opacity(0.45))
                .padding(.bottom, 40)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { intro = true }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                orbBob = true
            }
        }
    }
}
