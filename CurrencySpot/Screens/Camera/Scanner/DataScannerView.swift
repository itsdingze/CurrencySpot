//
//  DataScannerView.swift
//  CurrencySpot
//

import SwiftUI
import VisionKit

/// Wraps VisionKit's live scanner. Recognition stays on `.text()` so the app
/// sees every number and decides for itself which ones are price candidates.
struct DataScannerView: UIViewControllerRepresentable {
    let isScanning: Bool
    let proxy: DataScannerProxy
    let onItemsChanged: ([RecognizedTextItem]) -> Void
    let onItemTapped: (UUID) -> Void

    func makeUIViewController(context: Context) -> ScannerHostController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            // .fast over .balanced: .balanced waits for stable frames and adds
            // seconds of latency. Price-tag text is large, and the freeze path
            // covers the high-accuracy case with the still-image recognizer.
            qualityLevel: .fast,
            recognizesMultipleItems: true,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isGuidanceEnabled: false,
            isHighlightingEnabled: false
        )
        scanner.delegate = context.coordinator
        context.coordinator.observeRecognizedItems(of: scanner)
        let host = ScannerHostController(scanner: scanner)
        host.onScanningStarted = { [weak coordinator = context.coordinator, weak scanner] in
            guard let coordinator, let scanner else { return }
            coordinator.observeRecognizedItems(of: scanner)
        }
        proxy.host = host
        return host
    }

    func updateUIViewController(_ host: ScannerHostController, context: Context) {
        context.coordinator.onItemsChanged = onItemsChanged
        context.coordinator.onItemTapped = onItemTapped
        host.wantsScanning = isScanning
        host.syncScanning()
    }

    static func dismantleUIViewController(_ host: ScannerHostController, coordinator: Coordinator) {
        coordinator.stopObserving()
        host.scanner.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onItemsChanged: onItemsChanged, onItemTapped: onItemTapped)
    }

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var onItemsChanged: ([RecognizedTextItem]) -> Void
        var onItemTapped: (UUID) -> Void
        private var observationTask: Task<Void, Never>?

        init(onItemsChanged: @escaping ([RecognizedTextItem]) -> Void, onItemTapped: @escaping (UUID) -> Void) {
            self.onItemsChanged = onItemsChanged
            self.onItemTapped = onItemTapped
        }

        func observeRecognizedItems(of scanner: DataScannerViewController) {
            observationTask?.cancel()
            observationTask = Task { [weak self, weak scanner] in
                guard let scanner else { return }
                // The stream finishes whenever scanning stops (freeze, tab
                // switch, backgrounding); the host re-subscribes on the next
                // successful start, so one pass per scan session is enough.
                for await items in scanner.recognizedItems {
                    guard let self, !Task.isCancelled else { return }
                    self.onItemsChanged(items.compactMap(RecognizedTextItem.init))
                }
                guard let self, !Task.isCancelled else { return }
                self.onItemsChanged([])
            }
        }

        func stopObserving() {
            observationTask?.cancel()
            observationTask = nil
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {
            onItemTapped(item.id)
        }
    }
}

private extension RecognizedTextItem {
    init?(item: RecognizedItem) {
        guard case let .text(text) = item else { return nil }
        self.init(id: item.id, transcript: text.transcript, bounds: CGRect(quad: item.bounds))
    }
}

private extension CGRect {
    /// Axis-aligned bounding box of the scanner's four-corner quad.
    init(quad: RecognizedItem.Bounds) {
        let minX = min(quad.topLeft.x, quad.topRight.x, quad.bottomLeft.x, quad.bottomRight.x)
        let maxX = max(quad.topLeft.x, quad.topRight.x, quad.bottomLeft.x, quad.bottomRight.x)
        let minY = min(quad.topLeft.y, quad.topRight.y, quad.bottomLeft.y, quad.bottomRight.y)
        let maxY = max(quad.topLeft.y, quad.topRight.y, quad.bottomLeft.y, quad.bottomRight.y)
        self.init(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
