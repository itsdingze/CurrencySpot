//
//  ClearAllDataUseCase.swift
//  CurrencySpot
//

import Foundation

// MARK: - ClearAllDataUseCase

/// Owns the cross-cutting "clear everything" action: wipes the repository
/// (persistence, caches, fetch stamps, sync coverage), then tells each interested
/// feature to reset its published state.
///
/// Reset signal mechanism: ViewModels register reset closures through the
/// DependencyContainer at wiring time. This keeps Settings free of sibling-VM
/// references and is trivially testable (register a spy closure, run execute()).
final class ClearAllDataUseCase {
    private let repository: DataClearing
    private var resetHandlers: [@MainActor () async -> Void] = []

    init(repository: DataClearing) {
        self.repository = repository
    }

    /// Registers a feature's state reset, run after every successful clear.
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
