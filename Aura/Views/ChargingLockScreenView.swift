import SwiftUI

/// Full-bleed “lock screen” charging canvas shown while power is connected.
struct ChargingLockScreenView: View {
    @EnvironmentObject private var battery: BatteryMonitor
    @State private var ringPulse = false
    @State private var orbDrift = false
    @State private var boltFlash = false

    var body: some View {
        GeometryReader { geo in
            let ringSize = min(geo.size.width * 0.72, 320.0)

            ZStack {
                atmosphere

                VStack(spacing: 0) {
                    Spacer(minLength: geo.safeAreaInsets.top + 28)

                    brandHeader
                        .opacity(0.95)

                    Spacer()

                    ZStack {
                        ChargeRing(progress: battery.level, lineWidth: 14)
                            .frame(width: ringSize, height: ringSize)
                            .scaleEffect(ringPulse ? 1.02 : 1.0)
                            .shadow(color: ChargeTheme.ember.opacity(0.45), radius: ringPulse ? 36 : 18)

                        VStack(spacing: 6) {
                            Image(systemName: battery.state == .full ? "bolt.fill" : "bolt.circle.fill")
                                .font(.system(size: 28, weight: .semibold))
                                .foregroundStyle(ChargeTheme.molten)
                                .symbolEffect(.pulse, options: .repeating, isActive: battery.state == .charging)
                                .scaleEffect(boltFlash ? 1.08 : 1.0)

                            HStack(alignment: .firstTextBaseline, spacing: 2) {
                                Text(battery.percentText)
                                    .font(.system(size: 72, weight: .thin, design: .rounded))
                                    .foregroundStyle(.white)
                                    .contentTransition(.numericText())

                                Text("%")
                                    .font(.system(size: 28, weight: .light, design: .rounded))
                                    .foregroundStyle(ChargeTheme.mist)
                                    .padding(.bottom, 10)
                            }

                            Text(battery.statusLabel.uppercased())
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .tracking(3.2)
                                .foregroundStyle(ChargeTheme.ember)
                        }
                    }

                    Spacer()

                    VStack(spacing: 10) {
                        Text(battery.estimatedWattsLabel)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(ChargeTheme.mist)

                        Text("Lock screen Live Activity active")
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .opacity(battery.activityEnabled ? 1 : 0)
                    }
                    .padding(.bottom, max(36, geo.safeAreaInsets.bottom + 24))
                }
                .padding(.horizontal, 28)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                ringPulse = true
                orbDrift = true
            }
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                boltFlash = true
            }
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 8) {
            Text("AURA")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .tracking(8)
                .foregroundStyle(.white)

            Text("iPhone 17 Pro Max")
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.42))
        }
    }

    private var atmosphere: some View {
        ZStack {
            ChargeTheme.night

            Circle()
                .fill(ChargeTheme.ember.opacity(0.22))
                .frame(width: 340, height: 340)
                .blur(radius: 100)
                .offset(x: orbDrift ? 40 : -20, y: orbDrift ? -160 : -120)

            Circle()
                .fill(ChargeTheme.ice.opacity(0.12))
                .frame(width: 280, height: 280)
                .blur(radius: 90)
                .offset(x: orbDrift ? -60 : 30, y: orbDrift ? 220 : 260)

            // Soft vignette for OLED lock-screen feel
            RadialGradient(
                colors: [.clear, .black.opacity(0.55)],
                center: .center,
                startRadius: 80,
                endRadius: 520
            )
            .ignoresSafeArea()
        }
        .ignoresSafeArea()
    }
}

struct ChargeRing: View {
    var progress: Double
    var lineWidth: CGFloat = 12

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(
                    AngularGradient(
                        colors: [ChargeTheme.ember, ChargeTheme.molten, ChargeTheme.ice, ChargeTheme.ember],
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.6), value: progress)
        }
    }
}
