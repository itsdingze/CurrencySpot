import Foundation

struct OnboardingCard: Identifiable {
    var symbol: String
    var title: LocalizedStringResource
    var subTitle: LocalizedStringResource

    var id: String { symbol }
}
