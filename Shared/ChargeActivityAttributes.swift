import Foundation
import ActivityKit

struct ChargeActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var level: Double
        var isCharging: Bool
        var status: String
        var voltageText: String
        var currentText: String
        var isFastCharging: Bool
        var updatedAt: Date
    }

    var deviceName: String
}
