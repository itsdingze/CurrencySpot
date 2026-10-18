import Foundation
import Observation

@Observable
final class TrendsStore {
    private(set) var trends: [Trend] = []

    func replace(with trends: [Trend]) {
        self.trends = trends
    }
}
