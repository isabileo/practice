import SwiftUI

struct IdleHomeView: View {
    @EnvironmentObject private var battery: BatteryMonitor
    @State private var glow = false

    var body: some View {
        ZStack {
            atmosphere

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 48)

                Text("AURA")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .tracking(6)
                    .foregroundStyle(.white)

                Text("Stylish charging for lock screen & StandBy.")
                    .font(.system(size: 18, weight: .regular, design: .rounded))
                    .foregroundStyle(ChargeTheme.mist)
                    .padding(.top, 12)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                batteryChip

                VStack(alignment: .leading, spacing: 14) {
                    tipRow(icon: "bolt.fill", title: "Connect a charger", detail: "Aura fills the screen the moment power arrives.")
                    tipRow(icon: "lock.iphone", title: "Lock Screen Live Activity", detail: "Charge % stays visible while the phone is locked.")
                    tipRow(icon: "sofa.fill", title: "StandBy on Pro Max", detail: "MagSafe on a nightstand lights the Aura face.")
                }
                .padding(.top, 36)

                #if targetEnvironment(simulator)
                Button {
                    battery.previewForceCharging(true, level: max(battery.level, 0.58))
                } label: {
                    Text("Preview charging lock screen")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(ChargeTheme.ember.gradient)
                        .foregroundStyle(.black)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .padding(.top, 32)
                .padding(.bottom, 28)
                #else
                Color.clear.frame(height: 28)
                #endif
            }
            .padding(.horizontal, 28)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private var batteryChip: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ChargeTheme.ember.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "battery.75")
                    .foregroundStyle(ChargeTheme.molten)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(battery.percentText)% · \(battery.statusLabel)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(battery.estimatedWattsLabel)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
            }
            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private func tipRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(ChargeTheme.ember)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var atmosphere: some View {
        ZStack {
            ChargeTheme.night.ignoresSafeArea()
            Circle()
                .fill(ChargeTheme.ember.opacity(glow ? 0.2 : 0.1))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 90, y: -200)
        }
    }
}
