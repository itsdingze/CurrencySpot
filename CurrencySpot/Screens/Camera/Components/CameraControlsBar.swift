import PhotosUI
import SwiftUI

struct CameraControlsBar: View {
    let capturePhoto: () async throws -> UIImage?

    @Environment(CameraViewModel.self) private var viewModel
    @State private var pickedPhoto: PhotosPickerItem?

    var body: some View {
        AdaptiveGlassContainer {
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
        }
        .onChange(of: pickedPhoto) { _, item in
            guard let item else { return }
            Task {
                await viewModel.importPhoto(loading: { try await item.loadTransferable(type: Data.self) })
                if pickedPhoto == item { pickedPhoto = nil }
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
            shutterContent
                .frame(width: 64, height: 64)
                .adaptiveGlassBackground(in: .circle, isInteractive: true) {
                    Circle().stroke(.white, lineWidth: 3)
                }
        }
        .accessibilityLabel(shutterLabel)
        .accessibilityShowsLargeContentViewer {
            if viewModel.frozenImage == nil {
                Label(.cameraShutterFreeze, systemImage: "circle.fill")
            } else {
                Label(.cameraShutterResume, systemImage: "xmark")
            }
        }
    }

    private var shutterLabel: LocalizedStringResource {
        viewModel.frozenImage == nil ? .cameraShutterFreeze : .cameraShutterResume
    }

    @ViewBuilder
    private var shutterContent: some View {
        if viewModel.frozenImage == nil {
            Circle()
                .fill(.white)
                .frame(width: 56, height: 56)
        } else {
            Image(systemName: "xmark")
                .font(.appTitle2)
                .foregroundStyle(.white)
        }
    }

    private var torchSymbol: String {
        viewModel.isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill"
    }

    private var torchButton: some View {
        Button(.cameraFlashlight, systemImage: torchSymbol) {
            viewModel.toggleTorch()
        }
        .labelStyle(.iconOnly)
        .foregroundStyle(viewModel.isTorchOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.primary))
        .buttonStyle(.controlButton)
        .accessibilityValue(torchState)
        .accessibilityAddTraits(.isToggle)
        .accessibilityShowsLargeContentViewer {
            Label(.cameraFlashlight, systemImage: torchSymbol)
        }
    }

    private var torchState: LocalizedStringResource {
        viewModel.isTorchOn ? .cameraFlashlightOn : .cameraFlashlightOff
    }

    private var photoImportButton: some View {
        PhotosPicker(selection: $pickedPhoto, matching: .images) {
            Label(.cameraImportPhoto, systemImage: "photo.on.rectangle")
                .labelStyle(.iconOnly)
        }
        .buttonStyle(.controlButton)
        .accessibilityShowsLargeContentViewer {
            Label(.cameraImportPhoto, systemImage: "photo.on.rectangle")
        }
    }
}

#if DEBUG
#Preview {
    let container = DependencyContainer.preview()

    ZStack {
        Color(white: 0.2).ignoresSafeArea()
        CameraControlsBar(capturePhoto: { nil })
    }
    .withDependencyContainer(container)
}
#endif
