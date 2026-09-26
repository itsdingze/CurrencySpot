import Foundation
import SwiftData

private nonisolated let miniChartEncoder = JSONEncoder()
private nonisolated let miniChartDecoder = JSONDecoder()

@Model
nonisolated final class TrendData {
    @Attribute(.unique) var currencyCode: String
    var weeklyChange: Double

    // Stored as Data rather than [Double]: CoreData cannot serialize the array form.
    private var miniChartDataStorage: Data = Data()

    var miniChartData: [Double] {
        get {
            guard !miniChartDataStorage.isEmpty,
                  let decoded = try? miniChartDecoder.decode([Double].self, from: miniChartDataStorage) else {
                return []
            }
            return decoded
        }
        set {
            miniChartDataStorage = (try? miniChartEncoder.encode(newValue)) ?? Data()
        }
    }

    init(currencyCode: String, weeklyChange: Double, miniChartData: [Double]) {
        self.currencyCode = currencyCode
        self.weeklyChange = weeklyChange
        self.miniChartDataStorage = (try? miniChartEncoder.encode(miniChartData)) ?? Data()
    }
}

// MARK: - Entity <-> Domain Mapping

nonisolated extension TrendData {
    func toDomain() throws -> Trend {
        Trend(
            currencyCode: try CurrencyCode(validating: currencyCode),
            weeklyChange: weeklyChange,
            miniChartData: miniChartData
        )
    }

    convenience init(from value: Trend) {
        self.init(
            currencyCode: value.currencyCode.rawValue,
            weeklyChange: value.weeklyChange,
            miniChartData: value.miniChartData
        )
    }
}
