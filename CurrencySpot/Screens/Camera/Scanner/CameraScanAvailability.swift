import VisionKit

enum CameraScanAvailability {
    static var isSupported: Bool {
        #if DEBUG && targetEnvironment(simulator)
        return true
        #else
        return DataScannerViewController.isSupported
        #endif
    }
}
