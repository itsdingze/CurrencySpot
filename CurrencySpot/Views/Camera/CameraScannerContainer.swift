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

        // The scanner reports item bounds in its own full-screen view space,
        // so the overlay must live in that same full-bleed coordinate space.
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
                onBadgeTap: { viewModel.showBadgeDetail(for: $0) }
            )
        }
        .ignoresSafeArea()
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
            VStack(spacing: 16) {
                NoPricesHint(detectedItems: viewModel.detectedItems, isLive: viewModel.frozenImage == nil)
                CameraControlsBar(capturePhoto: { try await scannerProxy.capturePhoto() })
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
            currencyPicker(for: destination)
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
                openInConverter: { viewModel.openInConverter(item) }
            )
        }
    }
}
