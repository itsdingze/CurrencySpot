//
//  CameraView.swift
//  CurrencySpot
//

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
        // Camera-app look: this tab is always dark, whatever the system is.
        // Scoped via the environment so the rest of the app keeps following
        // the system scheme (preferredColorScheme would flip the window).
        .environment(\.colorScheme, .dark)
    }
}

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    CameraView()
        .withDependencyContainer(.preview())
        .environment(AppState.shared)
}
#endif
