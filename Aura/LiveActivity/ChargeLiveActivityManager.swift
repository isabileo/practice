import Foundation
import ActivityKit

actor ChargeLiveActivityManager {
    private var activity: Activity<ChargeActivityAttributes>?

    func sync(level: Double, isCharging: Bool, status: String) async -> Bool {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await endAll()
            return false
        }

        let state = ChargeActivityAttributes.ContentState(
            level: level,
            isCharging: isCharging,
            status: status,
            updatedAt: Date()
        )

        if isCharging {
            if let activity {
                await activity.update(ActivityContent(state: state, staleDate: nil))
            } else {
                let attributes = ChargeActivityAttributes(deviceName: "iPhone 17 Pro Max")
                activity = try? Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            }
            return activity != nil
        } else {
            await endAll()
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
    }

    private func endAll() async {
        for activity in Activity<ChargeActivityAttributes>.activities {
            await activity.end(
                ActivityContent(
                    state: ChargeActivityAttributes.ContentState(
                        level: activity.content.state.level,
                        isCharging: false,
                        status: "On battery",
                        updatedAt: Date()
                    ),
                    staleDate: nil
                ),
                dismissalPolicy: .immediate
            )
        }
        activity = nil
    }
}
