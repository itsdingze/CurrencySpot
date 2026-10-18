import Foundation

protocol AllDataRefreshing {
    func execute() async throws
}

extension RefreshAllDataUseCase: AllDataRefreshing {}
