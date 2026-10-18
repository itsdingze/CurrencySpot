import Foundation

nonisolated enum ToastType: Sendable {
    case dataRefreshing, preferencesReset
}

nonisolated struct ToastData: Identifiable, Sendable {
    let id = UUID()
    let type: ToastType

    var message: LocalizedStringResource {
        switch type {
        case .dataRefreshing: .toastDataRefreshingMessage
        case .preferencesReset: .toastPreferencesResetMessage
        }
    }

    var icon: String {
        switch type {
        case .dataRefreshing: "arrow.clockwise.circle.fill"
        case .preferencesReset: "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}
