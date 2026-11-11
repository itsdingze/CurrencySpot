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
        lastUpdatedDisplay(in: .current)
    }

    func lastUpdatedDisplay(in locale: Locale) -> String {
        formatted(.dateTime.year().month().day().hour().minute().locale(locale))
    }

    func savedRatesDisplay(relativeTo now: Date) -> String {
        let style = Date.FormatStyle.dateTime.month().day().hour().minute().locale(Locale.current)
        let isThisYear = Calendar.current.isDate(self, equalTo: now, toGranularity: .year)
        return formatted(isThisYear ? style : style.year())
    }
}
