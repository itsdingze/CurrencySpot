//
//  SearchField.swift
//  CurrencySpot
//

import SwiftUI

/// The magnifier + text field + clear-button search bar shared by the currency
/// lists and pickers. A later design phase swaps these for `.searchable` in one place.
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
        .padding(10)
        .background(Color.tertiaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
