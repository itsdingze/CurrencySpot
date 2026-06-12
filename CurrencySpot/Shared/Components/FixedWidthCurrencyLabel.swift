//
//  FixedWidthCurrencyLabel.swift
//  CurrencySpot
//

import SwiftUI

/// Currency code over an invisible "WWI" template so every code renders at the
/// same width (the font is not monospaced). Shared by the calculator and camera
/// currency buttons.
struct FixedWidthCurrencyLabel: View {
    let code: String

    var body: some View {
        ZStack(alignment: .center) {
            Text("WWI")
                .foregroundStyle(.clear)

            Text(code)
                .contentTransition(.numericText())
        }
        .font(.appHeadline.bold())
    }
}

#Preview {
    VStack {
        FixedWidthCurrencyLabel(code: "USD")
        FixedWidthCurrencyLabel(code: "EUR")
    }
    .padding()
}
