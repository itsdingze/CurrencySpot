//
//  CameraScannerContainer.swift
//  CurrencySpot
//

import SwiftUI

/// Live camera feed (or a frozen still) with detection overlay,
/// currency pair control, and capture controls.
@available(iOS 18.0, *)
struct CameraScannerContainer: View {
    @Environment(CameraViewModel.self) private var viewModel
    @Environment(AppState.self) private var appState
    @Environment(\.scenePhase) private var scenePhase
    @State private var scannerProxy = DataScannerProxy()

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            Color.black
                .ignoresSafeArea()

            // The scanner reports item bounds in its own view space, so the
            // overlay must share the preview's exact frame. The frame spans
            // the safe area; captures are center-cropped to its aspect so the
            // frozen frame lands at the identical size.
            ZStack {
                #if !targetEnvironment(simulator)
                DataScannerView(
                    isScanning: viewModel.isScanning,
                    proxy: scannerProxy,
                    onItemsChanged: { viewModel.updateLiveRecognizedItems($0) },
                    onItemTapped: { viewModel.toggleConversion(for: $0) }
                )
                #else
                Color.black
                #endif

                if let frozenImage = viewModel.frozenImage {
                    StillFrameView(image: frozenImage)
                }

                DetectionOverlayView(
                    items: viewModel.detectedItems,
                    targetCurrency: viewModel.targetCurrency,
                    onOutlineTap: { viewModel.toggleConversion(for: $0) },
                    onPlateTap: { viewModel.showBadgeDetail(for: $0) }
                )
            }
            .clipShape(.rect(cornerRadius: 32))
            // Controls anchor to the feed's own edges, not the safe area,
            // so their padding tracks the rounded frame.
            .overlay(alignment: .top) {
                CurrencyPairControl()
                    .padding(.top, 24)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: 16) {
                    ScanStatusCapsule(
                        isLive: viewModel.frozenImage == nil,
                        hasPrices: viewModel.hasPrices,
                        isRecognizingStill: viewModel.isRecognizingStill
                    )
                    CameraControlsBar(capturePhoto: { try await scannerProxy.capturePhoto() })
                }
                .padding(.bottom, 24)
            }
            .padding(.bottom, 24)
        }
        .onChange(of: viewModel.availableRates) {
            viewModel.refreshConversions()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                scannerProxy.syncScanning()
            } else {
                // Going inactive: extinguish the torch while the device is
                // still configurable, and keep the button state truthful —
                // the system kills the torch with the session anyway.
                viewModel.turnTorchOff()
            }
        }
        .onChange(of: appState.selectedTab) {
            viewModel.turnTorchOff()
        }
        .onDisappear {
            viewModel.turnTorchOff()
        }
        .sheet(item: $viewModel.destination) { destination in
            // preferredColorScheme darkens the whole enclosing presentation,
            // UIKit chrome included (sheet background, search bar, toolbar) —
            // an environment override only reaches the SwiftUI views.
            currencyPicker(for: destination)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private func currencyPicker(for destination: CameraViewModel.Destination) -> some View {
        @Bindable var viewModel = viewModel
        switch destination {
        case .basePicker:
            CurrencyPickerView(selectedCurrency: $viewModel.baseCurrency, exchangeRates: viewModel.availableRates)
        case .targetPicker:
            CurrencyPickerView(selectedCurrency: $viewModel.targetCurrency, exchangeRates: viewModel.availableRates)
        case let .badgeDetail(item):
            // Same height-fitting sheet as the accent color picker.
            if #available(iOS 26, *) {
                DynamicSheet(animation: .snappy) {
                    badgeDetail(for: item)
                }
            } else {
                badgeDetail(for: item)
                    .presentationDetents([.height(320)])
            }
        }
    }

    private func badgeDetail(for item: DetectedItem) -> some View {
        BadgeDetailView(
            item: item,
            baseCurrency: viewModel.baseCurrency,
            targetCurrency: viewModel.targetCurrency,
            openInConverter: { viewModel.openInConverter(item) },
            hideConversion: { viewModel.hideConversion(for: item.id) }
        )
    }
}
