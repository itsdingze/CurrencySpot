//
//  CameraAccessDeniedView.swift
//  CurrencySpot
//

import SwiftUI

/// Full-screen state when camera access was denied. No dead camera view.
struct CameraAccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        ContentUnavailableView {
            Label("Camera Access Is Off", systemImage: "video.slash")
        } description: {
            Text("Turn on camera access in Settings to convert prices with your camera.")
        } actions: {
            Button("Open Settings") {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    openURL(settingsURL)
                }
            }
            .buttonStyle(.borderedProminent)
        }
        .fontDesign(.rounded)
        .background(Color.background)
    }
}

#Preview {
    CameraAccessDeniedView()
}
