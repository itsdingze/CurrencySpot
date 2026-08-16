import SwiftUI

struct FixedWidthCurrencyLabel: View {
    let code: CurrencyCode

    var body: some View {
        ZStack(alignment: .center) {
            Text("WWI")
                .foregroundStyle(.clear)

            Text(code.rawValue)
                .contentTransition(.numericText())
        }
        .font(.appHeadline.bold())
    }
}

#Preview {
    VStack {
        FixedWidthCurrencyLabel(code: .usd)
        FixedWidthCurrencyLabel(code: .eur)
    }
    .padding()
}
