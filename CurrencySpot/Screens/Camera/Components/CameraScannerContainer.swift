import IdentifiedCollections
import SwiftUI

struct CameraScannerContainer: View {
    @Environment(CameraViewModel.self) private var viewModel
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var scannerProxy = DataScannerProxy()
    @State private var containerHeight: CGFloat = 0
    @State private var badgeDetailFittedHeight: CGFloat?

    private static let fittedSheetHeightLimit: CGFloat = 0.75

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
                        .appAccent(settingsViewModel.accentColor.color)
                        .environment(\.colorScheme, .dark)
                    }
                    .id(ObjectIdentifier(frozenImage))
                } else {
                    detectionOverlay(isLive: true)
                }
            }
            .clipShape(.rect(cornerRadius: 32))
            .overlay(alignment: .top) {
                VStack(spacing: Spacing.element) {
                    CurrencyPairControl()
                    if let notice = viewModel.ratesNotice {
                        RatesNoticeCapsule(notice: notice)
                            .padding(.horizontal, Spacing.screenInset)
                    }
                }
                .padding(.top, Spacing.screenInset)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: Spacing.section) {
                    if viewModel.canConvertPrices {
                        ScanStatusCapsule(
                            isLive: viewModel.frozenImage == nil,
                            hasPrices: viewModel.hasSettledPrices,
                            hasOutlines: viewModel.hasSettledNumbers,
                            isRecognizingStill: viewModel.isRecognizingStill
                        )
                    }
                    CameraControlsBar(capturePhoto: { try await scannerProxy.capturePhoto() })
                }
                .padding(.bottom, Spacing.screenInset)
            }
            .padding(.bottom, Spacing.screenInset)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
        .onChange(of: viewModel.availableRates) {
            viewModel.refreshConversions()
        }
        .onChange(of: viewModel.frozenImage != nil && viewModel.hasPrices) { _, detected in
            if detected {
                AccessibilityNotification.Announcement(String(localized: .cameraAnnouncementStillPricesDetected)).post()
            }
        }
        .onChange(of: viewModel.frozenImage == nil && viewModel.hasSettledPrices) { _, detected in
            if detected, viewModel.destination == nil {
                AccessibilityNotification.Announcement(String(localized: .cameraAnnouncementLivePriceDetected)).post()
            }
        }
        .onChange(of: viewModel.frozenImage != nil && !viewModel.isRecognizingStill && !viewModel.hasPrices) { _, empty in
            if empty {
                AccessibilityNotification.Announcement(String(localized: frozenEmptyAnnouncement)).post()
            }
        }
        .onChange(of: viewModel.ratesNotice) { _, notice in
            if let notice, notice == .missingPairRate, appState.selectedTab == .camera {
                AccessibilityNotification.Announcement(String(localized: notice.accessibilityLabel)).post()
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
            // An environment colorScheme override misses the sheet's UIKit chrome; preferredColorScheme reaches it.
            currencyPicker(for: destination)
                .preferredColorScheme(.dark)
        }
    }

    private var frozenEmptyAnnouncement: LocalizedStringResource {
        if !viewModel.canConvertPrices, let notice = viewModel.ratesNotice { return notice.accessibilityLabel }
        return viewModel.hasSettledNumbers ? .cameraAnnouncementNumbersOnly : .cameraAnnouncementNoPricesFound
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
                .presentationDetents(badgeDetailDetents)
        }
    }

    private var badgeDetailDetents: Set<PresentationDetent> {
        guard let badgeDetailFittedHeight else { return [.medium] }
        guard badgeDetailFittedHeight <= containerHeight * Self.fittedSheetHeightLimit else { return [.large] }
        return [.height(badgeDetailFittedHeight)]
    }

    private func badgeDetail(for snapshot: DetectedItem) -> some View {
        BadgeDetailView(
            item: snapshot,
            baseCurrency: viewModel.baseCurrency,
            targetCurrency: viewModel.targetCurrency,
            openInConverter: { viewModel.openInConverter(snapshot) },
            hideConversion: { viewModel.hideConversion(for: snapshot.id) },
            onFittedHeightChange: { badgeDetailFittedHeight = $0 }
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
