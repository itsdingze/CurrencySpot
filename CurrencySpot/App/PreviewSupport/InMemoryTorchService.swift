#if DEBUG

    import Foundation

    final class InMemoryTorchService: TorchService {
        private(set) var requestedStates: [Bool] = []
        private let hasTorch: Bool

        init(hasTorch: Bool = true) {
            self.hasTorch = hasTorch
        }

        func setTorch(enabled: Bool) -> Bool {
            requestedStates.append(enabled)
            return hasTorch && enabled
        }
    }

#endif
