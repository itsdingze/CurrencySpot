import SwiftUI
import WidgetKit

@main
struct CurrencySpotWidgetsBundle: WidgetBundle {
    var body: some Widget {
        PairRateWidget()
        RateListWidget()
        ScanPricesControl()
    }
}
