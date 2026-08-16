import Foundation

extension Double {
    var toStringMax2Decimals: String {
        formatted(.number.precision(.fractionLength(0 ... 2)))
    }

    var toStringMax4Decimals: String {
        formatted(.number.precision(.fractionLength(0 ... 4)))
    }
}
