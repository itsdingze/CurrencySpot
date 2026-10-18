import SwiftUI

struct CameraPermissionPrimer: View {
    let requestAccess: () async -> Void

    var body: some View {
        CameraStateScreen(
            icon: "camera.viewfinder",
            title: .cameraPermissionTitle,
            message: .cameraPermissionMessage,
            buttonTitle: .cameraPermissionAction,
            action: { Task { await requestAccess() } }
        )
    }
}

#Preview {
    CameraPermissionPrimer(requestAccess: {})
}
