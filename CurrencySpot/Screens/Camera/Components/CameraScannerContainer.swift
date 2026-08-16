import SwiftUI

struct CameraScannerContainer: View {
    @Environment(CameraViewModel.self) private var viewModel
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var scannerProxy = DataScannerProxy()

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            Color.black
                .ignoresSafeArea()

            ZStack {
                #if !targetEnvironment(simulator)
                DataScannerView(
                    isScanning: viewModel.isScanning,
                    proxy: scannerProxy,
                    onItemsChanged: { viewModel.updateLiveRecognizedItems($0) },
                    onItemTapped: { viewModel.toggleConversion(for: $0) }
                )
                .opacity(viewModel.frozenImage == nil ? 1 : 0)
                #else
                Color.black
                #endif

                if let frozenImage = viewModel.frozenImage {
                    ZoomableScrollView {
                        ZStack {
                            StillFrameView(image: frozenImage)
                            detectionOverlay(isLive: false)
                        }
                        .environment(viewModel)
                        .accentColor(settingsViewModel.accentColor.color)
                        .environment(\.colorScheme, .dark)
                    }
                    .id(ObjectIdentifier(frozenImage))
                } else {
                    detectionOverlay(isLive: true)
                }
            }
            .clipShape(.rect(cornerRadius: 32))
            .overlay(alignment: .top) {
                CurrencyPairControl()
                    .padding(.top, Spacing.screenInset)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: Spacing.section) {
                    ScanStatusCapsule(
                        isLive: viewModel.frozenImage == nil,
                        hasPrices: viewModel.hasPrices,
                        isRecognizingStill: viewModel.isRecognizingStill
                    )
                    CameraControlsBar(capturePhoto: { try await scannerProxy.capturePhoto() })
                }
                .padding(.bottom, Spacing.screenInset)
            }
            .padding(.bottom, Spacing.screenInset)
        }
        .onChange(of: viewModel.availableRates) {
            viewModel.refreshConversions()
        }
        .onChange(of: viewModel.frozenImage != nil && viewModel.hasPrices) { _, detected in
            if detected {
                AccessibilityNotification.Announcement("Prices detected. Swipe to explore.").post()
            }
        }
        .onChange(of: viewModel.frozenImage == nil && viewModel.hasPrices) { _, detected in
            if detected {
                AccessibilityNotification.Announcement("Price detected. Swipe right to hear the conversion, or tap the shutter to freeze and review.").post()
            }
        }
        .onChange(of: viewModel.frozenImage != nil && !viewModel.isRecognizingStill && !viewModel.hasPrices) { _, empty in
            if empty {
                AccessibilityNotification.Announcement("No prices found. Tap Resume camera to try again.").post()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                scannerProxy.syncScanning()
            } else {
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

    private func detectionOverlay(isLive: Bool) -> some View {
        DetectionOverlayView(
            items: viewModel.detectedItems.elements,
            targetCurrency: viewModel.targetCurrency,
            isLive: isLive,
            onOutlineTap: { viewModel.toggleConversion(for: $0) },
            onPlateTap: { viewModel.showBadgeDetail(for: $0) }
        )
    }

    @ViewBuilder
    private func currencyPicker(for destination: CameraViewModel.Destination) -> some View {
        @Bindable var viewModel = viewModel
        switch destination {
        case .basePicker:
            NavigationStack {
                CurrencyPickerView(
                    selectedCurrency: $viewModel.baseCurrency,
                    exchangeRates: viewModel.availableRates,
                    favoriteCurrencies: settingsViewModel.favoriteCurrencies
                )
            }
        case .targetPicker:
            NavigationStack {
                CurrencyPickerView(
                    selectedCurrency: $viewModel.targetCurrency,
                    exchangeRates: viewModel.availableRates,
                    favoriteCurrencies: settingsViewModel.favoriteCurrencies
                )
            }
        case let .badgeDetail(snapshot):
            badgeDetail(for: snapshot)
                .presentationDetents([.fraction(0.4)])
        }
    }

    private func badgeDetail(for snapshot: DetectedItem) -> some View {
        let item = viewModel.detectedItem(for: snapshot.id) ?? snapshot
        return BadgeDetailView(
            item: item,
            baseCurrency: viewModel.baseCurrency,
            targetCurrency: viewModel.targetCurrency,
            openInConverter: { viewModel.openInConverter(item) },
            hideConversion: { viewModel.hideConversion(for: item.id) }
        )
    }
}

#if DEBUG
#Preview {
    CameraScannerContainer()
        .withDependencyContainer(.preview())
        .environment(\.colorScheme, .dark)
}
#endif
