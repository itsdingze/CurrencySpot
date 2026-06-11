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

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: icon)
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text(title)
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text(message)
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: action) {
                    Text(buttonTitle)
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                }
                .tint(Color.accentColor)
                .buttonStyle(.borderedProminent)
                .accessibilityHint(buttonHint)
            }

            Spacer()
        }
        .safeAreaPadding(.horizontal, 36)
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
