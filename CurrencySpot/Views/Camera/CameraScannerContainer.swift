//
//  CameraScannerContainer.swift
//  CurrencySpot
//

import SwiftUI

/// Live camera feed (or a frozen still) with detection overlay,
/// currency pair control, capture controls, and rate-age chip.
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
            // overlay must share the preview's exact frame. The 3:4 portrait
            // frame matches the sensor, so the live feed shows the full field
            // of view and the frozen capture lands at the identical size.
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
            .aspectRatio(3.0 / 4.0, contentMode: .fit)
            .overlay(alignment: .bottom) {
                ScanStatusCapsule(
                    isLive: viewModel.frozenImage == nil,
                    hasPrices: viewModel.hasPrices,
                    isRecognizingStill: viewModel.isRecognizingStill
                )
                .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Center the preview between the physical top of the screen and
            // the bottom safe-area edge, Camera-app style.
            .ignoresSafeArea(edges: .top)
        }
        .overlay(alignment: .top) {
            VStack(spacing: 8) {
                CurrencyPairControl()
                if !appState.networkMonitor.isConnected {
                    rateAgeChip
                }
            }
            .padding(.top, 8)
        }
        .overlay(alignment: .bottom) {
            CameraControlsBar(capturePhoto: { try await scannerProxy.capturePhoto() })
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
            // Sheets are new presentation roots, so the tab's dark
            // environment doesn't reach them — re-apply it.
            currencyPicker(for: destination)
                .environment(\.colorScheme, .dark)
        }
    }

    /// Offline rate-age indicator, wording consistent with the app's offline banner.
    private var rateAgeChip: some View {
        Label("Using cached data · \(viewModel.rateFreshness)", systemImage: "wifi.slash")
            .font(.system(.caption, design: .rounded))
            .foregroundStyle(Color.textSecondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.regularMaterial, in: .capsule)
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
            BadgeDetailView(
                item: item,
                baseCurrency: viewModel.baseCurrency,
                targetCurrency: viewModel.targetCurrency,
                rateUsed: viewModel.rateUsed,
                rateFreshness: viewModel.rateFreshness,
                openInConverter: { viewModel.openInConverter(item) },
                hideConversion: { viewModel.hideConversion(for: item.id) }
            )
        }
    }
}
