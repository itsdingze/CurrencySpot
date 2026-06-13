//
//  SearchField.swift
//  CurrencySpot
//

import SwiftUI

/// The magnifier + text field + clear-button search bar shared by the currency
/// lists and pickers.
struct SearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.textSecondary)

            TextField(prompt, text: $text)
                .autocorrectionDisabled()
                .accessibilityLabel("Search currencies")
                .accessibilityHint("Enter currency code or name to filter the list")
                .accessibilityInputLabels(["Search", "Filter", "Find currency"])

            if !text.isEmpty {
                Button(action: clearText) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.textSecondary)
                }
                .accessibilityLabel("Clear search")
                .accessibilityHint("Clears the search text")
                .accessibilityInputLabels(["Clear", "Reset search"])
            }
        }
        .padding(.fieldPadding)
        .adaptiveGlassBackground(in: .capsule, isInteractive: true) {
            RoundedRectangle(cornerRadius: .cardRadius)
                .fill(Color.tertiaryBackground)
        }
    }

    private func clearText() {
        text = ""
    }
}

#Preview {
    @Previewable @State var text = "EUR"

    SearchField(prompt: "Search currency code or name", text: $text)
        .padding()
}
