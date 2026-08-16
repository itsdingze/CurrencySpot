import Foundation

extension Date {
    var chartDisplay: String {
        TimeZoneManager.formatForChartDisplay(self)
    }
}
