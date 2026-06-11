//
//  CameraAccessDeniedView.swift
//  CurrencySpot
//

import SwiftUI

/// Full-screen state when camera access was denied. No dead camera view.
struct CameraAccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)

                    Text("Camera Access Is Off")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)

                    Text("Turn on camera access in Settings to convert prices with your camera.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                        openURL(settingsURL)
                    }
                } label: {
                    Text("Open Settings")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                }
                .tint(Color.accentColor)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Opens the Settings app to enable camera access")
            }

            Spacer()
        }
        .safeAreaPadding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background.ignoresSafeArea())
    }
}

#Preview {
    CameraAccessDeniedView()
}
