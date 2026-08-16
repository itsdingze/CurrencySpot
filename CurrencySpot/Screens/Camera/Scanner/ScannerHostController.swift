import UIKit
import VisionKit

// startScanning() must run from viewDidAppear: called earlier it throws because the
// scanner's view is not in a window yet, and that failure is silent — the live feed
// stays unrecognized until something retriggers scanning.
final class ScannerHostController: UIViewController {
    let scanner: DataScannerViewController
    private let logger: LoggerService
    var wantsScanning = true

    var onScanningStarted: (() -> Void)?

    private var startTask: Task<Void, Never>?
    private var hasAppliedInitialZoom = false

    init(scanner: DataScannerViewController, logger: LoggerService = OSLogLoggerService()) {
        self.scanner = scanner
        self.logger = logger
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        addChild(scanner)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        syncScanning()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        startTask?.cancel()
        scanner.stopScanning()
    }

    func syncScanning() {
        if wantsScanning, scanner.isScanning { return }
        startTask?.cancel()
        if wantsScanning {
            startTask = Task { [weak self, logger] in
                var lastError: Error?
                for _ in 0..<10 {
                    guard let self, self.wantsScanning, !Task.isCancelled else { return }
                    guard !self.scanner.isScanning else { return }
                    guard self.viewIfLoaded?.window != nil else { return }
                    do {
                        try self.scanner.startScanning()
                        self.applyInitialZoomIfNeeded()
                        self.onScanningStarted?()
                        return
                    } catch {
                        lastError = error
                        try? await Task.sleep(for: .milliseconds(300))
                    }
                }
                logger.error(
                    "DataScanner failed to start after retries: \(String(describing: lastError))",
                    category: .ui
                )
            }
        } else if scanner.isScanning {
            scanner.stopScanning()
        }
    }

    // Zoom set before scanning starts does not stick, so this runs after the first
    // successful start, and only once so session restarts keep the user's pinch zoom.
    private func applyInitialZoomIfNeeded() {
        guard !hasAppliedInitialZoom else { return }
        hasAppliedInitialZoom = true
        scanner.zoomFactor = max(1, scanner.minZoomFactor)
    }
}
