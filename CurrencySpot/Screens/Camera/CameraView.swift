import SwiftUI

struct CameraView: View {
    @Environment(CameraViewModel.self) private var viewModel

    var body: some View {
        Group {
            switch viewModel.authorization {
            case .notDetermined:
                CameraPermissionPrimer {
                    await viewModel.requestCameraAccess()
                }
            case .denied:
                CameraAccessDeniedView()
            case .authorized:
                CameraScannerContainer()
            }
        }
        .environment(\.colorScheme, .dark)
        .onChange(of: isAuthorized) { _, authorized in
            if authorized {
                AccessibilityNotification.Announcement("Camera ready. Point at a price tag.").post()
            }
        }
    }

    private var isAuthorized: Bool {
        if case .authorized = viewModel.authorization { return true }
        return false
    }
}

#if DEBUG
#Preview {
    CameraView()
        .withDependencyContainer(.preview())
}
#endif
