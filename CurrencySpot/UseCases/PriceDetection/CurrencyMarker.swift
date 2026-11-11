import Foundation

struct CurrencyMarker {
    enum Placement {
        case beforeNumber
        case afterNumber
        case afterNumberOnly
    }

    let span: Range<Int>
    let placement: Placement
    var needsMoneyShape = false
    var allowsPunctuationGap = false
    var isCents = false
    var ranksLast = false
    var allowsSpacedGrouping = true
    var doublesAsAcronym = false
}
