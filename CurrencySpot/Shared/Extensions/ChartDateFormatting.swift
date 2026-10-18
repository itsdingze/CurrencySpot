import Foundation

extension Date {
    var chartDisplay: String {
        formatted(.dateTime.month().day().year().locale(Locale.current))
    }

    var rateDayDisplay: String {
        var style = Date.FormatStyle.dateTime.month().day().year().locale(Locale.current)
        style.timeZone = CETCalendar.timeZone
        return formatted(style)
    }

    var lastUpdatedDisplay: String {
        formatted(.dateTime.year().month().day().hour().minute().locale(Locale.current))
    }
}
