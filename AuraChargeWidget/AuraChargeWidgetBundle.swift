import WidgetKit
import SwiftUI

@main
struct AuraChargeWidgetBundle: WidgetBundle {
    var body: some Widget {
        ChargeLiveActivityWidget()
        ChargeStandByWidget()
    }
}
