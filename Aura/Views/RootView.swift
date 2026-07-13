import SwiftUI

struct RootView: View {
    @EnvironmentObject private var battery: BatteryMonitor
    @State private var appear = false

    var body: some View {
        ZStack {
            ChargeTheme.night.ignoresSafeArea()

            if battery.isCharging {
                ChargingLockScreenView()
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            } else {
                IdleHomeView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.55), value: battery.isCharging)
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { appear = true }
        }
    }
}

#Preview("Charging") {
    let battery = BatteryMonitor()
    battery.previewForceCharging(true, level: 0.64)
    return RootView().environmentObject(battery)
}

#Preview("Idle") {
    let battery = BatteryMonitor()
    battery.previewForceCharging(false, level: 0.42)
    return RootView().environmentObject(battery)
}
