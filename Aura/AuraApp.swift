import SwiftUI

@main
struct AuraApp: App {
    @StateObject private var battery = BatteryMonitor()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(battery)
                .preferredColorScheme(.dark)
                .onAppear {
                    battery.start()
                }
        }
    }
}
