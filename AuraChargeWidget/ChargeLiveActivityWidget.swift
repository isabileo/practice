import ActivityKit
import WidgetKit
import SwiftUI

struct ChargeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargeActivityAttributes.self) { context in
            LockScreenChargeView(state: context.state, deviceName: context.attributes.deviceName)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Label(context.state.isFastCharging ? "Fast" : "Aura", systemImage: "bolt.fill")
                            .font(.headline)
                            .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.18))
                        Text("\(context.state.voltageText) · \(context.state.currentText)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(Int((context.state.level * 100).rounded()))%")
                        .font(.title2.weight(.semibold).monospacedDigit())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.state.isFastCharging ? "bolt.badge.automatic.fill" : "bolt.fill")
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.32))
            } compactTrailing: {
                Text("\(Int((context.state.level * 100).rounded()))%")
                    .font(.caption.monospacedDigit())
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.18))
            }
        }
    }
}

struct LockScreenChargeView: View {
    let state: ChargeActivityAttributes.ContentState
    let deviceName: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.12), lineWidth: 6)
                    .frame(width: 52, height: 52)
                Circle()
                    .trim(from: 0, to: state.level)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.18),
                                Color(red: 1.0, green: 0.78, blue: 0.32),
                                Color(red: 0.55, green: 0.82, blue: 1.0)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 52, height: 52)

                Image(systemName: state.isFastCharging ? "bolt.badge.automatic.fill" : "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.32))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.isFastCharging ? "Fast charging confirmed" : state.status)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text("\(state.voltageText)  ·  \(state.currentText)  ·  \(deviceName)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(Int((state.level * 100).rounded()))%")
                .font(.system(size: 28, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }
}
