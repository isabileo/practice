import SwiftUI

struct GameOverView: View {
    @ObservedObject var engine: GameEngine
    @State private var show = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()

            VStack(spacing: 18) {
                Text("RUN ENDED")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .tracking(4)
                    .foregroundStyle(GameTheme.coral)

                Text("\(engine.score)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded).monospacedDigit())
                    .foregroundStyle(GameTheme.foam)

                Text(engine.score >= engine.highScore && engine.score > 0
                     ? "New best charge"
                     : "Best  \(engine.highScore)")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(GameTheme.amber.opacity(0.9))

                HStack(spacing: 12) {
                    Button(action: engine.returnToMenu) {
                        Text("MENU")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .tracking(2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(GameTheme.foam.opacity(0.1))
                            .foregroundStyle(GameTheme.foam)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .stroke(GameTheme.foam.opacity(0.2), lineWidth: 1)
                            )
                    }

                    Button(action: engine.start) {
                        Text("AGAIN")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .tracking(2)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                LinearGradient(
                                    colors: [GameTheme.coral, GameTheme.amber],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundStyle(Color(red: 0.08, green: 0.06, blue: 0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
                .padding(.top, 8)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(GameTheme.deep.opacity(0.95))
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(GameTheme.teal.opacity(0.25), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 32)
            .scaleEffect(show ? 1 : 0.92)
            .opacity(show ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) { show = true }
        }
    }
}
