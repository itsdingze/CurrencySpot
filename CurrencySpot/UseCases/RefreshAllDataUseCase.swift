import Foundation

// MARK: - RefreshAllDataUseCase

final class RefreshAllDataUseCase {
    private let repository: DataClearing
    private var resetHandlers: [@MainActor () async -> Void] = []

    init(repository: DataClearing) {
        self.repository = repository
    }

    func registerResetHandler(_ handler: @escaping @MainActor () async -> Void) {
        resetHandlers.append(handler)
    }

    func execute() async throws {
        try await repository.clearAllData()
        for handler in resetHandlers {
            await handler()
        }
    }
}
