//
//  CameraPermissionPrimer.swift
//  CurrencySpot
//

import SwiftUI

/// One-line explanation shown before triggering the system camera prompt.
struct CameraPermissionPrimer: View {
    let requestAccess: () async -> Void

    var body: some View {
        ContentUnavailableView {
            Label("Convert Prices with Your Camera", systemImage: "camera.viewfinder")
        } description: {
            Text("Point your camera at a price tag or menu and see every price in your currency.")
        } actions: {
            Button("Enable Camera") {
                Task { await requestAccess() }
            }
            .buttonStyle(.borderedProminent)
        }
        .fontDesign(.rounded)
        .background(Color.background)
    }
}

#Preview {
    CameraPermissionPrimer(requestAccess: {})
}
