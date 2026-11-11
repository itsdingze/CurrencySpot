import SwiftUI
import WidgetKit

struct PairRateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "PairRateWidget", intent: PairRateConfiguration.self, provider: PairRateProvider()) { entry in
            PairRateWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .environment(\.locale, .appLanguage(in: .appGroup))
        }
        .configurationDisplayName(.widgetPairRateName)
        .description(.widgetPairRateDescription)
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
