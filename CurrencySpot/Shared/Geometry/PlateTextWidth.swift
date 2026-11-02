import SwiftUI
import UIKit

enum PlateTextWidth {
    static func of(_ text: String, fontSize: CGFloat, legibilityWeight: LegibilityWeight?) -> CGFloat {
        let weight: UIFont.Weight = legibilityWeight == .bold ? .heavy : .semibold
        let base = UIFont.systemFont(ofSize: fontSize, weight: weight)
        let font = base.fontDescriptor.withDesign(.rounded).map { UIFont(descriptor: $0, size: fontSize) } ?? base
        return (text as NSString).size(withAttributes: [.font: font]).width.rounded(.up)
    }
}
