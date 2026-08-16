import Foundation

struct OnboardingCard: Identifiable {
    var symbol: String
    var title: String
    var subTitle: String

    var id: String { "\(symbol)-\(title)" }
}
