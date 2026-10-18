import Foundation

extension Date {
    var chartDisplay: String {
        formatted(.dateTime.month().day().year().locale(Locale.current))
    }

    var lastUpdatedDisplay: String {
        formatted(.dateTime.year().month().day().hour().minute().locale(Locale.current))
    }
}
