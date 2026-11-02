import SwiftUI
import Vision
import VisionKit

struct DataScannerView: UIViewControllerRepresentable {
    let isScanning: Bool
    let proxy: DataScannerProxy
    let onItemsChanged: ([RecognizedTextItem]) -> Void
    let onItemTapped: (UUID) -> Void

    func makeUIViewController(context: Context) -> ScannerHostController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.text()],
            qualityLevel: .balanced,
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
        fileprivate var onItemsChanged: ([RecognizedTextItem]) -> Void
        fileprivate var onItemTapped: (UUID) -> Void
        private var observationTask: Task<Void, Never>?

        init(onItemsChanged: @escaping ([RecognizedTextItem]) -> Void, onItemTapped: @escaping (UUID) -> Void) {
            self.onItemsChanged = onItemsChanged
            self.onItemTapped = onItemTapped
        }

        fileprivate func observeRecognizedItems(of scanner: DataScannerViewController) {
            observationTask?.cancel()
            observationTask = Task { [weak self, weak scanner] in
                guard let scanner else { return }
                for await items in scanner.recognizedItems {
                    guard let self, !Task.isCancelled else { return }
                    self.onItemsChanged(items.compactMap(RecognizedTextItem.init))
                }
                guard let self, !Task.isCancelled else { return }
                self.onItemsChanged([])
            }
        }

        fileprivate func stopObserving() {
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
        self.init(
            id: item.id,
            transcript: text.transcript,
            quad: Quad(
                topLeft: item.bounds.topLeft,
                topRight: item.bounds.topRight,
                bottomRight: item.bounds.bottomRight,
                bottomLeft: item.bounds.bottomLeft
            ),
            characterSpans: Self.characterSpans(of: text.observation, matching: text.transcript)
        )
    }

    static func characterSpans(of observation: VNRecognizedTextObservation, matching transcript: String) -> [ClosedRange<CGFloat>]? {
        guard transcript.contains(where: \.isNumber),
              let reading = observation.topCandidates(1).first,
              reading.string == transcript
        else { return nil }
        let line = Quad(observation)
        var spans: [ClosedRange<CGFloat>] = []
        var index = transcript.startIndex
        while index < transcript.endIndex {
            let next = transcript.index(after: index)
            guard let glyph = try? reading.boundingBox(for: index ..< next) else { return nil }
            spans.append(line.baselineSpan(of: Quad(glyph)))
            index = next
        }
        return spans
    }
}

private extension Quad {
    init(_ rectangle: VNRectangleObservation) {
        self.init(
            topLeft: rectangle.topLeft,
            topRight: rectangle.topRight,
            bottomRight: rectangle.bottomRight,
            bottomLeft: rectangle.bottomLeft
        )
    }
}
