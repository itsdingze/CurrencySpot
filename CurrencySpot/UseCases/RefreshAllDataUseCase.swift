import Foundation

// MARK: - ArchiveBackfillResetting

protocol ArchiveBackfillResetting {
    func reset()
}

extension BackfillArchiveUseCase: ArchiveBackfillResetting {}

// MARK: - RefreshAllDataUseCase

final class RefreshAllDataUseCase {
    private let repository: DataClearing
    private let backfill: ArchiveBackfillResetting

    init(repository: DataClearing, backfill: ArchiveBackfillResetting) {
        self.repository = repository
        self.backfill = backfill
    }

    func execute() async throws {
        try await repository.clearAllData()
        backfill.reset()
    }
}
