import ActivityKit
import WidgetKit
import SwiftUI

struct ChargeLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargeActivityAttributes.self) { context in
            // Lock Screen / Banner
            LockScreenChargeView(state: context.state, deviceName: context.attributes.deviceName)
                .activityBackgroundTint(Color.black.opacity(0.82))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Aura", systemImage: "bolt.fill")
                        .font(.headline)
                        .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.18))
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
                Image(systemName: "bolt.fill")
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
        HStack(spacing: 16) {
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

                Image(systemName: "bolt.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color(red: 1.0, green: 0.78, blue: 0.32))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(state.isCharging ? "Charging with Aura" : state.status)
                    .font(.headline)
                    .foregroundStyle(.white)
                Text(deviceName)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }

            Spacer()

            Text("\(Int((state.level * 100).rounded()))%")
                .font(.system(size: 28, weight: .light, design: .rounded).monospacedDigit())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}
