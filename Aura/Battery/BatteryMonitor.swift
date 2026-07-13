import Foundation
import UIKit
import Combine
import ActivityKit

/// Estimated electrical readout for the charging canvas.
/// iOS does not expose real USB-C voltage/current to third-party apps;
/// values follow typical iPhone 17 Pro Max USB-PD charge curves.
struct ChargeElectricals: Equatable {
    var voltageVolts: Double
    var currentAmps: Double
    var watts: Double
    var isFastCharging: Bool
    var modeLabel: String

    static let idle = ChargeElectricals(
        voltageVolts: 0,
        currentAmps: 0,
        watts: 0,
        isFastCharging: false,
        modeLabel: "Unplugged"
    )

    var voltageText: String { String(format: "%.1f V", voltageVolts) }
    var currentText: String { String(format: "%.2f A", currentAmps) }
    var wattsText: String { String(format: "%.0f W", watts) }
}

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var level: Double = 0.72
    @Published private(set) var state: UIDevice.BatteryState = .unplugged
    @Published private(set) var isCharging: Bool = false
    @Published private(set) var activityEnabled: Bool = false
    @Published private(set) var electricals: ChargeElectricals = .idle

    private var cancellables = Set<AnyCancellable>()
    private let activityManager = ChargeLiveActivityManager()
    private var previewOverride: Bool?

    var percentText: String {
        "\(Int((level * 100).rounded()))"
    }

    var statusLabel: String {
        switch state {
        case .charging: return electricals.isFastCharging ? "Fast charging" : "Charging"
        case .full: return "Fully charged"
        case .unplugged: return "On battery"
        case .unknown: return "Battery"
        @unknown default: return "Battery"
        }
    }

    var estimatedWattsLabel: String {
        switch state {
        case .charging:
            if electricals.isFastCharging {
                return "Fast charging confirmed · \(electricals.wattsText)"
            }
            return "Standard charge · \(electricals.wattsText)"
        case .full:
            return "Holding 100% · \(electricals.voltageText)"
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

        // Animate estimated V/A while plugged in (Simulator + live curve feel).
        Timer.publish(every: 1.2, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                #if targetEnvironment(simulator)
                if self.isCharging, self.level < 1 {
                    self.level = min(1, self.level + 0.008)
                }
                #endif
                self.recomputeElectricals(jitter: true)
                self.syncLiveActivity()
            }
            .store(in: &cancellables)
    }

    func refresh() {
        if previewOverride == true {
            recomputeElectricals(jitter: false)
            syncLiveActivity()
            return
        }
        if previewOverride == false {
            // Forced idle preview
            return
        }

        let device = UIDevice.current
        var nextLevel = Double(device.batteryLevel)
        if nextLevel < 0 { nextLevel = level }
        level = max(0, min(1, nextLevel))
        state = device.batteryState
        isCharging = state == .charging || state == .full
        recomputeElectricals(jitter: false)
        syncLiveActivity()
    }

    /// Preview / Simulator helper so designers can force the charging canvas.
    func previewForceCharging(_ on: Bool, level: Double = 0.67) {
        previewOverride = on
        isCharging = on
        state = on ? .charging : .unplugged
        self.level = level
        if !on {
            electricals = .idle
        }
        recomputeElectricals(jitter: false)
        syncLiveActivity()
    }

    private func recomputeElectricals(jitter: Bool) {
        guard isCharging else {
            electricals = .idle
            return
        }

        if state == .full || level >= 0.995 {
            electricals = ChargeElectricals(
                voltageVolts: 5.0,
                currentAmps: 0.05,
                watts: 0.3,
                isFastCharging: false,
                modeLabel: "Fully charged"
            )
            return
        }

        let jV = jitter ? Double.random(in: -0.08...0.08) : 0
        let jA = jitter ? Double.random(in: -0.06...0.06) : 0

        // iPhone 17 Pro Max–like USB-PD curve: peak fast charge then taper.
        let curve: (v: Double, a: Double, fast: Bool, mode: String)
        switch level {
        case ..<0.50:
            curve = (9.2 + jV, 3.35 + jA, true, "Fast charging")
        case ..<0.80:
            curve = (9.0 + jV, 2.45 + jA, true, "Fast charging")
        case ..<0.92:
            curve = (5.2 + jV * 0.5, 1.15 + jA * 0.5, false, "Standard charge")
        default:
            curve = (5.1 + jV * 0.3, 0.55 + jA * 0.3, false, "Trickle charge")
        }

        let volts = max(4.8, curve.v)
        let amps = max(0.05, curve.a)
        electricals = ChargeElectricals(
            voltageVolts: (volts * 10).rounded() / 10,
            currentAmps: (amps * 100).rounded() / 100,
            watts: ((volts * amps) * 10).rounded() / 10,
            isFastCharging: curve.fast,
            modeLabel: curve.mode
        )
    }

    private func syncLiveActivity() {
        Task {
            let enabled = await activityManager.sync(
                level: level,
                isCharging: isCharging,
                status: statusLabel,
                voltageText: electricals.voltageText,
                currentText: electricals.currentText,
                isFastCharging: electricals.isFastCharging
            )
            activityEnabled = enabled
        }
    }
}
