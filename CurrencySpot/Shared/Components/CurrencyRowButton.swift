//
//  CurrencyRowButton.swift
//  CurrencySpot
//

import SwiftUI

/// The code + name (+ optional checkmark) list cell shared by the currency
/// pickers. Selection styling and accessibility wrappers stay at the call sites.
struct CurrencyRowButton: View {
    let code: String
    let name: String
    var isSelected = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(code)
                    .font(.appHeadline.weight(.medium))

                Spacer()

                Text(name)
                    .font(.appSubheadline)
                    .foregroundStyle(Color.textSecondary)

                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, .hairlineGap)
        }
    }
}

#Preview {
    List {
        CurrencyRowButton(code: "EUR", name: "Euro", action: {})
        CurrencyRowButton(code: "JPY", name: "Japanese Yen", isSelected: true, action: {})
    }
    .listStyle(.plain)
}
