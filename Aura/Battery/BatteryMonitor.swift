import Foundation
import UIKit
import Combine
import ActivityKit

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var level: Double = 0.72
    @Published private(set) var state: UIDevice.BatteryState = .unplugged
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var activityEnabled: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let activityManager = ChargeLiveActivityManager()

    var percentText: String {
        "\(Int((level * 100).rounded()))"
    }

    var statusLabel: String {
        switch state {
        case .charging: return "Charging"
        case .full: return "Fully charged"
        case .unplugged: return "On battery"
        case .unknown: return "Battery"
        @unknown default: return "Battery"
        }
    }

    var estimatedWattsLabel: String {
        switch state {
        case .charging:
            if level < 0.8 { return "Fast charge · up to 40W" }
            return "Trickle · finishing up"
        case .full:
            return "Holding 100%"
        default:
            return "Plug in to wake Aura"
        }
    }

    func start() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        refresh()

        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)

        // Smooth demo pulse when running in Simulator without real hardware events.
        #if targetEnvironment(simulator)
        Timer.publish(every: 2.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self, self.isCharging, self.level < 1 else { return }
                self.level = min(1, self.level + 0.01)
                self.syncLiveActivity()
            }
            .store(in: &cancellables)
        #endif
    }

    func refresh() {
        let device = UIDevice.current
        var nextLevel = Double(device.batteryLevel)
        if nextLevel < 0 { nextLevel = level } // unknown → keep last
        level = max(0, min(1, nextLevel))
        state = device.batteryState
        isCharging = state == .charging || state == .full
        syncLiveActivity()
    }

    /// Preview / Simulator helper so designers can force the charging canvas.
    func previewForceCharging(_ on: Bool, level: Double = 0.67) {
        isCharging = on
        state = on ? .charging : .unplugged
        self.level = level
        syncLiveActivity()
    }

    private func syncLiveActivity() {
        Task {
            let enabled = await activityManager.sync(
                level: level,
                isCharging: isCharging,
                status: statusLabel
            )
            activityEnabled = enabled
        }
    }
}
