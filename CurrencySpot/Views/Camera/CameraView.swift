//
//  CameraView.swift
//  CurrencySpot
//

import SwiftUI

@available(iOS 18.0, *)
struct CameraView: View {
    @Environment(CameraViewModel.self) private var viewModel

    var body: some View {
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
}
