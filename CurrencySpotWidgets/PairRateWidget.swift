import SwiftUI
import WidgetKit

struct PairRateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PairRateWidget", intent: PairRateConfiguration.self, provider: PairRateProvider()) { entry in
            PairRateWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
        }
        .configurationDisplayName(.widgetPairRateName)
        .description(.widgetPairRateDescription)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
