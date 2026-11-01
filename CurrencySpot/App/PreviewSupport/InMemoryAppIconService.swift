#if DEBUG

    import Foundation

    final class InMemoryAppIconService: AppIconService {
        private(set) var alternateIconName: String?
        private(set) var requestedNames: [String?] = []
        var failure: Error?

        init(alternateIconName: String? = nil) {
            self.alternateIconName = alternateIconName
        }

        func setAlternateIconName(_ name: String?) async throws {
            requestedNames.append(name)
            if let failure { throw failure }
            alternateIconName = name
        }
    }

#endif
