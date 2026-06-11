//
//  CameraPermissionPrimer.swift
//  CurrencySpot
//

import SwiftUI

/// One-line explanation shown before triggering the system camera prompt.
struct CameraPermissionPrimer: View {
    let requestAccess: () async -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                    
                    Text("Convert Prices with Your Camera")
                        .font(.system(.title2, design: .rounded, weight: .bold))
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Point your camera at a price tag or menu and see every price in your currency.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
     
                Button {
                    Task { await requestAccess() }
                } label: {
                    Text("Enable Camera")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                }
                .tint(Color.accentColor)
                .buttonStyle(.borderedProminent)
                .accessibilityHint("Shows the system camera permission prompt")
            }
            
            Spacer()
        }
        .safeAreaPadding(.horizontal, 36)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background.ignoresSafeArea())
    }
}

#Preview {
    CameraPermissionPrimer(requestAccess: {})
}
