//
//  RefreshAllDataUseCase.swift
//  CurrencySpot
//

import Foundation

// MARK: - RefreshAllDataUseCase

/// Owns the cross-cutting "Refresh All Data" action: wipes the repository
/// (persistence, caches, fetch stamps, sync coverage), then runs every handler the
/// container registered — feature state resets followed by the post-wipe rebuild
/// (rate refetch plus the tiered history warm-up). The wipe itself stays a
/// repository concern (`DataClearing`); this use case is the intent on top of it.
///
/// Handler mechanism: closures register through the DependencyContainer at wiring
/// time. This keeps Settings free of sibling-VM references and is trivially
/// testable (register a spy closure, run execute()).
final class RefreshAllDataUseCase {
    private let repository: DataClearing
    private var resetHandlers: [@MainActor () async -> Void] = []

    init(repository: DataClearing) {
        self.repository = repository
    }

    /// Registers a handler run after every successful clear — a feature's state
    /// reset or a post-wipe rebuild step.
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
