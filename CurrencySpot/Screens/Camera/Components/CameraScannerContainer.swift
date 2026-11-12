import IdentifiedCollections
import SwiftUI
import TipKit

struct CameraScannerContainer: View {
    @Environment(CameraViewModel.self) private var viewModel
    @Environment(LiveCameraController.self) private var liveCamera
    @Environment(AppState.self) private var appState
    @Environment(SettingsViewModel.self) private var settingsViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.screenLayout) private var screenLayout
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var containerHeight: CGFloat = 0
    @State private var suggestsFreezing = false
    @State private var isVisible = false

    @ScaledMetric(relativeTo: .headline) private var tabletopControlsWidth: CGFloat = 248

    private static let fittedSheetHeightLimit: CGFloat = 0.75

    var body: some View {
        @Bindable var viewModel = viewModel

        ZStack {
            Color.black
                .ignoresSafeArea()

            if screenLayout == .wide {
                openLayout
            } else if screenLayout == .compact, horizontalSizeClass == .regular {
                uprightOpenLayout
            } else {
                FoldAdaptiveLayout {
                    phoneLayout
                } top: {
                    viewfinder
                        .padding(Spacing.screenInset)
                } bottom: {
                    stackedControls
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { containerHeight = $0 }
        .task {
            for await shouldDisplay in FreezeFrameTip().shouldDisplayUpdates {
                suggestsFreezing = shouldDisplay
            }
        }
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
            if phase != .active {
                viewModel.turnTorchOff()
            }
        }
        .onChange(of: appState.selectedTab) {
            viewModel.turnTorchOff()
        }
        .onChange(of: runsCamera, initial: true) { _, runs in
            if runs {
                liveCamera.start()
            } else {
                liveCamera.stop()
            }
        }
        .onChange(of: viewModel.stillRecognitionLanguages, initial: true) { _, languages in
            liveCamera.setLanguages(languages)
        }
        .onAppear {
            isVisible = true
        }
        .onDisappear {
            isVisible = false
            viewModel.turnTorchOff()
        }
        .sheet(item: $viewModel.destination) { destination in
            // An environment colorScheme override misses the sheet's UIKit chrome; preferredColorScheme reaches it.
            currencyPicker(for: destination)
                .preferredColorScheme(.dark)
        }
    }

    private var phoneLayout: some View {
        viewfinder
            .overlay(alignment: .top) {
                pairControls
                    .padding(.top, Spacing.screenInset)
            }
            .overlay(alignment: .bottom) {
                captureControls
                    .frame(maxWidth: screenLayout == .tent ? tabletopControlsWidth : nil)
                    .padding(.bottom, Spacing.screenInset)
            }
            .padding(.bottom, Spacing.screenInset)
    }

    private var openLayout: some View {
        viewfinder
            .overlay(alignment: .topTrailing) {
                pairControls
                    .padding([.top, .trailing], Spacing.screenInset)
            }
            .overlay(alignment: .trailing) {
                sideCaptureControls
            }
            .ignoresSafeArea(edges: .bottom)
    }

    private var uprightOpenLayout: some View {
        viewfinder
            .overlay(alignment: .top) {
                pairControls
                    .padding(.top, Spacing.screenInset)
            }
            .overlay(alignment: .trailing) {
                sideCaptureControls
            }
            .padding(.bottom, Spacing.screenInset)
    }

    private var stackedControls: some View {
        VStack(spacing: Spacing.section) {
            pairControls
            Spacer()
            captureControls
                .frame(maxWidth: tabletopControlsWidth)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.screenInset)
    }

    private var viewfinder: some View {
        ZStack {
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
                LiveViewfinder(overlay: detectionOverlay(isLive: true))
            }
        }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { liveCamera.previewSizeChanged($0) }
        .clipShape(.rect(cornerRadius: 32))
    }

    private var pairControls: some View {
        VStack(spacing: Spacing.element) {
            CurrencyPairControl()
            if let notice = viewModel.ratesNotice {
                RatesNoticeCapsule(notice: notice)
                    .padding(.horizontal, Spacing.screenInset)
            }
        }
    }

    private var captureControls: some View {
        VStack(spacing: Spacing.section) {
            scanStatus
            controlsBar(axis: .horizontal)
        }
    }

    private var sideCaptureControls: some View {
        HStack(spacing: Spacing.section) {
            scanStatus
            controlsBar(axis: .vertical)
        }
        .padding(.trailing, Spacing.screenInset)
    }

    @ViewBuilder
    private var scanStatus: some View {
        if viewModel.canConvertPrices {
            ScanStatusCapsule(
                isLive: viewModel.frozenImage == nil,
                hasPrices: viewModel.hasSettledPrices,
                hasOutlines: viewModel.hasSettledNumbers,
                isRecognizingStill: viewModel.isRecognizingStill,
                suggestsFreezing: suggestsFreezing
            )
        }
    }

    private func controlsBar(axis: Axis) -> some View {
        CameraControlsBar(axis: axis, capturePhoto: { try await liveCamera.capturePhoto() })
            .dynamicTypeSize(...DynamicTypeSize.accessibility1)
    }

    private var frozenEmptyAnnouncement: LocalizedStringResource {
        if !viewModel.canConvertPrices, let notice = viewModel.ratesNotice { return notice.accessibilityLabel }
        return viewModel.hasSettledNumbers ? .cameraAnnouncementNumbersOnly : .cameraAnnouncementNoPricesFound
    }

    private var runsCamera: Bool {
        isVisible && scenePhase == .active && appState.selectedTab == .camera && viewModel.isScanning
    }

    private func detectionOverlay(isLive: Bool) -> some View {
        DetectionOverlayView(
            items: viewModel.detectedItems.elements,
            targetCurrency: viewModel.targetCurrency,
            isLive: isLive,
            imageSize: isLive ? nil : viewModel.frozenImage?.size,
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
        }
    }

    private func badgeDetail(for snapshot: DetectedItem) -> some View {
        BadgeDetailView(
            item: snapshot,
            baseCurrency: viewModel.baseCurrency,
            targetCurrency: viewModel.targetCurrency,
            openInConverter: { viewModel.openInConverter(snapshot) },
            hideConversion: { viewModel.hideConversion(for: snapshot.id) },
            fullHeightThreshold: containerHeight * Self.fittedSheetHeightLimit
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
