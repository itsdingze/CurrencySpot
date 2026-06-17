//
//  CameraPermissionPrimer.swift
//  CurrencySpot
//

import SwiftUI

/// One-line explanation shown before triggering the system camera prompt.
struct CameraPermissionPrimer: View {
    let requestAccess: () async -> Void

    var body: some View {
        CameraStateScreen(
            icon: "camera.viewfinder",
            title: "Convert Prices with Your Camera",
            message: "Point your camera at a price tag or menu and see every price in your currency.",
            buttonTitle: "Get Started",
            buttonHint: "Continues to the camera",
            action: { Task { await requestAccess() } }
        )
    }
}

#Preview {
    CameraPermissionPrimer(requestAccess: {})
}
