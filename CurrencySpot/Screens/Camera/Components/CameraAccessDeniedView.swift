import SwiftUI

struct CameraAccessDeniedView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        CameraStateScreen(
            icon: "video.slash",
            title: .cameraAccessDeniedTitle,
            message: .cameraAccessDeniedMessage,
            buttonTitle: .cameraAccessDeniedAction,
            buttonHint: .cameraAccessDeniedActionAccessibilityHint,
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
