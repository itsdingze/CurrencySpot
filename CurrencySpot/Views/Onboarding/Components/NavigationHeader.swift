//
//  NavigationHeader.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 8/27/25.
//

import SwiftUI

struct NavigationHeader: View {
    @Binding var currentPage: Int
    let totalPages: Int
    let onBack: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 36) {
            backButton
            progressIndicator
            skipButton
        }
        .padding(.top, 36)
    }

    private var backButton: some View {
        Button(action: onBack) {
            Image(systemName: "chevron.left")
                .font(.system(.subheadline, weight: .medium))
                .foregroundColor(.primary)
        }
        .opacity(currentPage > 0 ? 1 : 0)
        .disabled(currentPage == 0)
        .accessibilityLabel("Go back")
        .accessibilityHint("Returns to the previous onboarding page")
    }

    private var progressIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0 ..< totalPages, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index <= currentPage ? Color.accentColor : Color.gray.opacity(0.3))
                    .frame(height: 4)
                    .animation(.snappy, value: currentPage)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Page \(currentPage + 1) of \(totalPages)")
        .accessibilityHint("Progress indicator showing current onboarding page")
    }

    private var skipButton: some View {
        Button("Skip", action: onSkip)
            .font(.system(.subheadline, design: .rounded, weight: .medium))
            .foregroundColor(.primary)
            .accessibilityLabel("Skip onboarding")
            .accessibilityHint("Skips chart feature tutorial and returns to main app")
    }
}

#Preview {
    @Previewable @State var currentPage = 0

    VStack {
        NavigationHeader(
            currentPage: $currentPage,
            totalPages: 3,
            onBack: {
                currentPage = max(0, currentPage - 1)
            },
            onSkip: {
                print("Skip tapped")
            }
        )

        Spacer()

        HStack {
            Button("Previous") {
                currentPage = max(0, currentPage - 1)
            }
            .disabled(currentPage == 0)

            Spacer()

            Text("Page \(currentPage + 1) of 3")

            Spacer()

            Button("Next") {
                currentPage = min(2, currentPage + 1)
            }
            .disabled(currentPage == 2)
        }
        .padding()
    }
    .padding()
}
