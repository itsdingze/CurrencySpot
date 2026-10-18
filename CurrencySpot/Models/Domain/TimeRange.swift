import Foundation

nonisolated enum TimeRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case fiveYears = "5Y"

    var id: String { rawValue }

    var displayName: LocalizedStringResource {
        switch self {
        case .oneWeek: .timeRangeOneWeekName
        case .oneMonth: .timeRangeOneMonthName
        case .threeMonths: .timeRangeThreeMonthsName
        case .sixMonths: .timeRangeSixMonthsName
        case .oneYear: .timeRangeOneYearName
        case .fiveYears: .timeRangeFiveYearsName
        }
    }

    var shortName: LocalizedStringResource {
        switch self {
        case .oneWeek: .timeRangeOneWeekShortName
        case .oneMonth: .timeRangeOneMonthShortName
        case .threeMonths: .timeRangeThreeMonthsShortName
        case .sixMonths: .timeRangeSixMonthsShortName
        case .oneYear: .timeRangeOneYearShortName
        case .fiveYears: .timeRangeFiveYearsShortName
        }
    }

    var accessibilityInputLabels: [LocalizedStringResource] {
        switch self {
        case .oneWeek:
            [.timeRangeOneWeekVoiceInputNumeral, .timeRangeOneWeekVoiceInputSpelledOut, .timeRangeOneWeekVoiceInputAlternative]
        case .oneMonth:
            [.timeRangeOneMonthVoiceInputNumeral, .timeRangeOneMonthVoiceInputSpelledOut, .timeRangeOneMonthVoiceInputAlternative]
        case .threeMonths:
            [.timeRangeThreeMonthsVoiceInputNumeral, .timeRangeThreeMonthsVoiceInputSpelledOut, .timeRangeThreeMonthsVoiceInputAlternative]
        case .sixMonths:
            [.timeRangeSixMonthsVoiceInputNumeral, .timeRangeSixMonthsVoiceInputSpelledOut, .timeRangeSixMonthsVoiceInputAlternative]
        case .oneYear:
            [.timeRangeOneYearVoiceInputNumeral, .timeRangeOneYearVoiceInputSpelledOut, .timeRangeOneYearVoiceInputAlternative]
        case .fiveYears:
            [.timeRangeFiveYearsVoiceInputNumeral, .timeRangeFiveYearsVoiceInputSpelledOut]
        }
    }

    func startDate(from endDate: Date) -> Date {
        let calendar = CETCalendar.calendar

        switch self {
        case .oneWeek:
            return calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .oneMonth:
            return calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: endDate) ?? endDate
        case .oneYear:
            return calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .fiveYears:
            return calendar.date(byAdding: .year, value: -5, to: endDate) ?? endDate
        }
    }

    var chartAxisDateFormat: Date.FormatStyle {
        var style: Date.FormatStyle = switch self {
        case .oneWeek, .oneMonth:
            .dateTime.month(.abbreviated).day()
        case .threeMonths, .sixMonths, .oneYear:
            .dateTime.month(.abbreviated)
        case .fiveYears:
            .dateTime.year()
        }
        style.timeZone = CETCalendar.timeZone
        return style
    }
}
