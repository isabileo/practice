import SwiftUI

/// Minimal waiting face — the full Aura charging canvas appears only when power is connected.
struct IdleHomeView: View {
    @EnvironmentObject private var battery: BatteryMonitor
    @State private var pulse = false

    var body: some View {
        ZStack {
            ChargeTheme.night.ignoresSafeArea()

            Circle()
                .fill(ChargeTheme.ember.opacity(pulse ? 0.16 : 0.08))
                .frame(width: 220, height: 220)
                .blur(radius: 70)
                .offset(y: -40)

            VStack(spacing: 16) {
                Text("AURA")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .tracking(8)
                    .foregroundStyle(.white)

                Text("Waiting for charger…")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
                    .foregroundStyle(ChargeTheme.mist)

                Text("App screen + animations play only when plugged in.")
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                #if targetEnvironment(simulator)
                Button {
                    battery.previewForceCharging(true, level: max(battery.level, 0.58))
                } label: {
                    Text("Connect charger")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ChargeTheme.ember.gradient)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.horizontal, 28)
                .padding(.top, 28)
                #endif
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}
