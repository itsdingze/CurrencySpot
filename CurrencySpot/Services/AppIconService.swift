import UIKit

protocol AppIconService {
    var alternateIconName: String? { get }
    func setAlternateIconName(_ name: String?) async throws
}

struct UIKitAppIconService: AppIconService {
    var alternateIconName: String? {
        UIApplication.shared.alternateIconName
    }

    func setAlternateIconName(_ name: String?) async throws {
        try await UIApplication.shared.setAlternateIconName(name)
    }
}
