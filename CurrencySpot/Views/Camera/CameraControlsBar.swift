//
//  CameraControlsBar.swift
//  CurrencySpot
//

import PhotosUI
import SwiftUI

/// Bottom controls: photo import on the left, shutter-style freeze in the center.
struct CameraControlsBar: View {
    let capturePhoto: () async throws -> UIImage?

    @Environment(CameraViewModel.self) private var viewModel
    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        ZStack {
            shutterButton
            HStack {
                photoImportButton
                Spacer()
                if viewModel.frozenImage == nil {
                    torchButton
                }
            }
            .padding(.horizontal, 32)
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                await viewModel.importPhoto(loading: { try await item.loadTransferable(type: Data.self) })
                pickedPhoto = nil
            }
        }
    }

    private func shutterTapped() {
        if viewModel.frozenImage != nil {
            viewModel.resumeLiveScanning()
        } else {
            Task { await viewModel.freezeFrame(capturing: capturePhoto) }
        }
    }

    private var shutterButton: some View {
        Button(action: shutterTapped) {
            if #available(iOS 26, *) {
                shutterContent
                    .frame(width: 64, height: 64)
                    .glassEffect(.regular, in: .circle)
            } else {
                ZStack {
                    Circle()
                        .stroke(.white, lineWidth: 3)
                        .frame(width: 64, height: 64)
                    shutterContent
                }
            }
        }
        .accessibilityLabel(viewModel.frozenImage == nil ? "Freeze frame" : "Resume camera")
        .accessibilityHint(viewModel.frozenImage == nil
            ? "Pauses the camera so you can read badges without holding the phone steady"
            : "Returns to the live camera feed")
    }

    @ViewBuilder
    private var shutterContent: some View {
        if viewModel.frozenImage == nil {
            Circle()
                .fill(.white)
                .frame(width: 56, height: 56)
        } else {
            Image(systemName: "xmark")
                .font(.system(.title2, design: .rounded).weight(.semibold))
                .foregroundStyle(.white)
        }
    }

    private var torchButton: some View {
        Button {
            viewModel.toggleTorch()
        } label: {
            Image(systemName: viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(viewModel.isTorchOn ? Color.accentColor : .primary)
                .frame(width: 48, height: 48)
                .adaptiveGlassBackground(in: .circle, isInteractive: true)
        }
        .accessibilityLabel(viewModel.isTorchOn ? "Turn flashlight off" : "Turn flashlight on")
    }

    private var photoImportButton: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .adaptiveGlassBackground(in: .circle, isInteractive: true)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Import photo")
        .accessibilityHint("Pick an image from your library to convert its prices")
    }
}

#Preview {
    let container = DependencyContainer.preview()

    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        CameraControlsBar(capturePhoto: { nil })
    }
    .withDependencyContainer(container)
}
