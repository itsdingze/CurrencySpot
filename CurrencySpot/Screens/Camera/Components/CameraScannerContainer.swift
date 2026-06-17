//
//  CameraScannerContainer.swift
//  CurrencySpot
//

import SwiftUI

/// Live camera feed (or a frozen still) with detection overlay,
/// currency pair control, and capture controls.
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
                // Hidden but still mounted (keeps the capture session alive) so
                // zooming out reveals black, not the live feed.
                .opacity(viewModel.frozenImage == nil ? 1 : 0)
                #else
                Color.black
                #endif

                if let frozenImage = viewModel.frozenImage {
                    // Still + overlay zoom together inside the scroll view so
                    // plates stay aligned. Hosting in UIKit drops the SwiftUI
                    // environment, so re-inject what the content reads; the id
                    // resets the zoom when a new still arrives.
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
            .clipShape(.rect(cornerRadius: .previewRadius))
            // Controls anchor to the feed's own edges, not the safe area,
            // so their padding tracks the rounded frame.
            .overlay(alignment: .top) {
                CurrencyPairControl()
                    .padding(.top, .screenInset)
            }
            .overlay(alignment: .bottom) {
                VStack(spacing: .sectionGap) {
                    ScanStatusCapsule(
                        isLive: viewModel.frozenImage == nil,
                        hasPrices: viewModel.hasPrices,
                        isRecognizingStill: viewModel.isRecognizingStill
                    )
                    CameraControlsBar(capturePhoto: { try await scannerProxy.capturePhoto() })
                }
                .padding(.bottom, .screenInset)
            }
            .padding(.bottom, .screenInset)
        }
        .onChange(of: viewModel.availableRates) {
            viewModel.refreshConversions()
        }
        // Fires once when a frozen frame's recognition surfaces prices — a
        // discrete capture, not the continuous live feed (which keeps
        // frozenImage nil), so VoiceOver isn't spammed every detection tick.
        .onChange(of: viewModel.frozenImage != nil && viewModel.hasPrices) { _, detected in
            if detected {
                AccessibilityNotification.Announcement("Prices detected. Swipe to explore.").post()
            }
        }
        // Live feed surfaced its first price: VoiceOver can't see the churning
        // plates, so steer the user to the swipe/freeze actions instead.
        .onChange(of: viewModel.frozenImage == nil && viewModel.hasPrices) { _, detected in
            if detected {
                AccessibilityNotification.Announcement("Price detected. Swipe right to hear the conversion, or tap the shutter to freeze and review.").post()
            }
        }
        // A frozen frame's recognition finished with nothing to convert.
        .onChange(of: viewModel.frozenImage != nil && !viewModel.isRecognizingStill && !viewModel.hasPrices) { _, empty in
            if empty {
                AccessibilityNotification.Announcement("No prices found. Tap Resume camera to try again.").post()
            }
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

    /// The price plates and tappable outlines, shared by the live feed and the
    /// frozen-still viewer. `isLive` swaps the live plates' per-element
    /// VoiceOver focus for one aggregated summary.
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
                CurrencyPickerView(selectedCurrency: $viewModel.baseCurrency, exchangeRates: viewModel.availableRates)
            }
        case .targetPicker:
            NavigationStack {
                CurrencyPickerView(selectedCurrency: $viewModel.targetCurrency, exchangeRates: viewModel.availableRates)
            }
        case let .badgeDetail(snapshot):
            badgeDetail(for: snapshot)
                .presentationDetents([.fraction(0.4)])
        }
    }

    private func badgeDetail(for snapshot: DetectedItem) -> some View {
        // Prefer the live item so fresh rates update an open sheet; fall back
        // to the presentation-time snapshot if the item left the frame.
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

// Preview factories are DEBUG-only; #Preview bodies compile in Release too.
#if DEBUG
#Preview {
    CameraScannerContainer()
        .withDependencyContainer(.preview())
        .environment(AppState.shared)
        .environment(\.colorScheme, .dark)
}
#endif
