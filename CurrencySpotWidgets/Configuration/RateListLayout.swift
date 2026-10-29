import WidgetKit

nonisolated enum RateListLayout {
    static func rowLimit(for family: WidgetFamily) -> Int {
        family == .systemLarge ? 7 : 2
    }
}
