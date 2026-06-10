//
//  ScannerHostController.swift
//  CurrencySpot
//

import UIKit
import VisionKit

/// Hosts the DataScanner and drives `startScanning()` from `viewDidAppear`.
/// Starting any earlier (e.g. from the first representable update) throws
/// because the scanner's view isn't in a window yet, and that silent failure
/// left the live feed unrecognized until something retriggered scanning.
@MainActor
final class ScannerHostController: UIViewController {
    let scanner: DataScannerViewController
    var wantsScanning = true

    private var startTask: Task<Void, Never>?

    init(scanner: DataScannerViewController) {
        self.scanner = scanner
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
        startTask?.cancel()
        if wantsScanning {
            // startScanning() can throw transiently (session warming up,
            // a capture still settling), so retry briefly instead of giving up.
            startTask = Task { @MainActor [weak self] in
                var lastError: Error?
                for _ in 0..<10 {
                    guard let self, self.wantsScanning, !Task.isCancelled else { return }
                    guard !self.scanner.isScanning else { return }
                    guard self.viewIfLoaded?.window != nil else { return }
                    do {
                        try self.scanner.startScanning()
                        return
                    } catch {
                        lastError = error
                        try? await Task.sleep(for: .milliseconds(300))
                    }
                }
                AppLogger.error(
                    "DataScanner failed to start after retries: \(String(describing: lastError))",
                    category: .ui
                )
            }
        } else if scanner.isScanning {
            scanner.stopScanning()
        }
    }
}
