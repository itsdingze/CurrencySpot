import AppIntents

nonisolated enum WidgetPeriod: String, AppEnum {
    case oneWeek
    case oneMonth
    case threeMonths
    case sixMonths
    case oneYear

    static let typeDisplayRepresentation: TypeDisplayRepresentation = "widget.parameter.period"

    static let caseDisplayRepresentations: [WidgetPeriod: DisplayRepresentation] = [
        .oneWeek: "timeRange.oneWeek.name",
        .oneMonth: "timeRange.oneMonth.name",
        .threeMonths: "timeRange.threeMonths.name",
        .sixMonths: "timeRange.sixMonths.name",
        .oneYear: "timeRange.oneYear.name",
    ]

    var timeRange: TimeRange {
        switch self {
        case .oneWeek: .oneWeek
        case .oneMonth: .oneMonth
        case .threeMonths: .threeMonths
        case .sixMonths: .sixMonths
        case .oneYear: .oneYear
        }
    }
}
