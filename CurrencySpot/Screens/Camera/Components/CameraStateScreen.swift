//
//  CameraStateScreen.swift
//  CurrencySpot
//

import SwiftUI

/// Shared full-screen layout for the camera tab's permission states:
/// an icon, a headline, an explanation, and a single call to action.
struct CameraStateScreen: View {
    let icon: String
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let buttonTitle: LocalizedStringKey
    var buttonHint: LocalizedStringKey? = nil
    let action: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: .blockGap) {
                VStack(spacing: .elementGap) {
                    Image(systemName: icon)
                        .font(.heroIcon)
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.appTitle2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .font(.appSubheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                actionButton
            }

            Spacer()
        }
        .safeAreaPadding(.horizontal, .onboardingInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background.ignoresSafeArea())
    }

    @ViewBuilder
    private var actionButton: some View {
        let button = Button(action: action) { Text(buttonTitle) }
            .buttonStyle(.primaryAction)
        if let buttonHint {
            button.accessibilityHint(buttonHint)
        } else {
            button
        }
    }
}

#Preview {
    CameraStateScreen(
        icon: "camera.viewfinder",
        title: "Convert Prices with Your Camera",
        message: "Point your camera at a price tag or menu and see every price in your currency.",
        buttonTitle: "Get Started",
        action: {}
    )
}
