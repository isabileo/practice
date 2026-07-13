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

                // Colorful flowers stream in from the USB-C charging socket
                ChargingFlowerField(isActive: true, size: geo.size)
                    .ignoresSafeArea()

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

                    VStack(spacing: 16) {
                        FastChargeBadge(isFast: battery.electricals.isFastCharging, mode: battery.electricals.modeLabel)

                        ElectricalMeters(electricals: battery.electricals)

                        Text(battery.estimatedWattsLabel)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(ChargeTheme.mist)

                        Text("Lock screen Live Activity active")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.35))
                            .opacity(battery.activityEnabled ? 1 : 0)
                    }
                    .padding(.bottom, max(28, geo.safeAreaInsets.bottom + 18))
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

struct FastChargeBadge: View {
    let isFast: Bool
    let mode: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isFast ? "bolt.badge.automatic.fill" : "bolt.fill")
                .font(.system(size: 13, weight: .bold))
            Text(isFast ? "FAST CHARGING CONFIRMED" : mode.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .tracking(1.4)
        }
        .foregroundStyle(isFast ? Color.black.opacity(0.85) : ChargeTheme.mist)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(isFast ? ChargeTheme.molten : Color.white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(isFast ? Color.clear : Color.white.opacity(0.12), lineWidth: 1)
        )
        .animation(.easeInOut(duration: 0.35), value: isFast)
    }
}

struct ElectricalMeters: View {
    let electricals: ChargeElectricals

    var body: some View {
        HStack(spacing: 0) {
            meter(title: "VOLTAGE", value: electricals.voltageVolts == 0 ? "—" : electricals.voltageText)
            Divider()
                .frame(height: 36)
                .overlay(Color.white.opacity(0.15))
            meter(title: "CURRENT", value: electricals.currentAmps == 0 ? "—" : electricals.currentText)
            Divider()
                .frame(height: 36)
                .overlay(Color.white.opacity(0.15))
            meter(title: "POWER", value: electricals.watts == 0 ? "—" : electricals.wattsText)
        }
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.06))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func meter(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.white.opacity(0.42))
            Text(value)
                .font(.system(size: 18, weight: .semibold, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
        .frame(maxWidth: .infinity)
    }
}
