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
    let buttonHint: LocalizedStringKey
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

                Button(action: action) {
                    Text(buttonTitle)
                        .padding(.horizontal, .chipPadding)
                }
                .buttonStyle(.primaryAction)
                .accessibilityHint(buttonHint)
            }

            Spacer()
        }
        .safeAreaPadding(.horizontal, .onboardingInset)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background.ignoresSafeArea())
    }
}

#Preview {
    CameraStateScreen(
        icon: "camera.viewfinder",
        title: "Convert Prices with Your Camera",
        message: "Point your camera at a price tag or menu and see every price in your currency.",
        buttonTitle: "Enable Camera",
        buttonHint: "Shows the system camera permission prompt",
        action: {}
    )
}
