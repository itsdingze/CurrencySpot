//
//  CameraAccessDeniedView.swift
//  CurrencySpot
//

import SwiftUI

/// Full-screen state when camera access was denied. No dead camera view.
struct CameraAccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        CameraStateScreen(
            icon: "video.slash",
            title: "Camera Access Is Off",
            message: "Turn on camera access in Settings to convert prices with your camera.",
            buttonTitle: "Open Settings",
            buttonHint: "Opens the Settings app to enable camera access",
            action: openSettings
        )
    }

    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(settingsURL)
    }
}

#Preview {
    CameraAccessDeniedView()
}
