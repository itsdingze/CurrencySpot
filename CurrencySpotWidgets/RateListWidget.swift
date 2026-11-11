import SwiftUI
import WidgetKit

struct RateListWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "RateListWidget", intent: RateListConfiguration.self, provider: RateListProvider()) { entry in
            RateListWidgetView(entry: entry)
                .containerBackground(.background, for: .widget)
                .environment(\.locale, .appLanguage(in: .appGroup))
        }
        .configurationDisplayName(.widgetRateListName)
        .description(.widgetRateListDescription)
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
