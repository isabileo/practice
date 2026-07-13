import WidgetKit
import SwiftUI

/// StandBy / home-screen style face for MagSafe charging on Pro Max nightstands.
struct ChargeStandByWidget: Widget {
    let kind = "ChargeStandByWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ChargeStandByProvider()) { entry in
            ChargeStandByView(entry: entry)
                .containerBackground(for: .widget) {
                    Color(red: 0.03, green: 0.04, blue: 0.07)
                }
        }
        .configurationDisplayName("Aura Charge")
        .description("Stylish battery face for StandBy while charging.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct ChargeStandByEntry: TimelineEntry {
    let date: Date
    let level: Double
    let isCharging: Bool
}

struct ChargeStandByProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargeStandByEntry {
        ChargeStandByEntry(date: Date(), level: 0.72, isCharging: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ChargeStandByEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargeStandByEntry>) -> Void) {
        // Widgets cannot read live battery directly in all contexts; Live Activity
        // carries the precise lock-screen state. StandBy shows a styled face.
        let entry = ChargeStandByEntry(date: Date(), level: 0.72, isCharging: true)
        completion(Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60))))
    }
}

struct ChargeStandByView: View {
    let entry: ChargeStandByEntry

    var body: some View {
        VStack(spacing: 10) {
            Text("AURA")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .tracking(4)
                .foregroundStyle(.white.opacity(0.7))

            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: entry.level)
                    .stroke(
                        AngularGradient(
                            colors: [
                                Color(red: 1.0, green: 0.55, blue: 0.18),
                                Color(red: 1.0, green: 0.78, blue: 0.32),
                                Color(red: 0.55, green: 0.82, blue: 1.0)
                            ],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                Text("\(Int((entry.level * 100).rounded()))%")
                    .font(.system(size: 28, weight: .thin, design: .rounded))
                    .foregroundStyle(.white)
            }
            .padding(8)

            Text(entry.isCharging ? "CHARGING" : "BATTERY")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .tracking(2)
                .foregroundStyle(Color(red: 1.0, green: 0.55, blue: 0.18))
        }
        .padding()
    }
}
