#if DEBUG

    import Foundation

    struct StubCameraPermissionService: CameraPermissionService {
        let status: CameraAuthorizationStatus
        let grantsAccess: Bool

        init(status: CameraAuthorizationStatus, grantsAccess: Bool = false) {
            self.status = status
            self.grantsAccess = grantsAccess
        }

        func currentStatus() -> CameraAuthorizationStatus {
            status
        }

        func requestAccess() async -> Bool {
            grantsAccess
        }
    }

#endif
