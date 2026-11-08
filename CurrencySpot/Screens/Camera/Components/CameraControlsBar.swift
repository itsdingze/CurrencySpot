import PhotosUI
import SwiftUI
import TipKit

struct CameraControlsBar: View {
    let capturePhoto: () async throws -> UIImage?

    @Environment(CameraViewModel.self) private var viewModel
    @State private var pickedPhoto: PhotosPickerItem?
    @ScaledMetric(relativeTo: .headline) private var shutterDiameter: CGFloat = 64
    @ScaledMetric(relativeTo: .headline) private var shutterFaceDiameter: CGFloat = 56
    @ScaledMetric(relativeTo: .headline) private var shutterRingWidth: CGFloat = 3
    private let freezeFrameTip = FreezeFrameTip()

    var body: some View {
        ZStack {
            AdaptiveGlassContainer {
                ZStack {
                    shutterButton
                    photoImportButton
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 32)
                }
            }
            if viewModel.frozenImage == nil {
                TorchButton(isOn: viewModel.isTorchOn, toggle: viewModel.toggleTorch)
                    .frame(maxWidth: .infinity, alignment: .trailing)
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
            freezeFrameTip.invalidate(reason: .actionPerformed)
            Task { await viewModel.freezeFrame(capturing: capturePhoto) }
        }
    }

    private var shutterButton: some View {
        Button(action: shutterTapped) {
            shutterContent
                .frame(width: shutterDiameter, height: shutterDiameter)
                .adaptiveGlassBackground(in: .circle, isInteractive: true) {
                    Circle().stroke(.white, lineWidth: shutterRingWidth)
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
                .frame(width: shutterFaceDiameter, height: shutterFaceDiameter)
                .scaleEffect(viewModel.isCapturing ? 0.8 : 1)
                .opacity(viewModel.isCapturing ? 0.6 : 1)
                .animation(.appQuickFade, value: viewModel.isCapturing)
        } else {
            Image(systemName: "xmark")
                .font(.appTitle2)
                .foregroundStyle(.white)
        }
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
