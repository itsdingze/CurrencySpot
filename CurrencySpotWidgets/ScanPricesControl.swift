import SwiftUI
import WidgetKit

struct ScanPricesControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "ScanPricesControl") {
            ControlWidgetButton(action: OpenScannerIntent()) {
                Label(.intentScanPricesTitle, systemImage: "camera.viewfinder")
            }
        }
        .displayName(.intentScanPricesTitle)
        .description(.intentScanPricesDescription)
    }
}
