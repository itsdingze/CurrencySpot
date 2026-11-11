import Foundation

nonisolated enum ToastType: Sendable {
    case dataRefreshing, preferencesReset, appIconUnchanged
}

nonisolated struct ToastData: Identifiable, Sendable {
    let id = UUID()
    let type: ToastType

    var message: LocalizedStringResource {
        switch type {
        case .dataRefreshing: .toastDataRefreshingMessage
        case .preferencesReset: .toastPreferencesResetMessage
        case .appIconUnchanged: .toastAppIconUnchangedMessage
        }
    }

    var isFailure: Bool {
        type == .appIconUnchanged
    }

    var icon: String {
        switch type {
        case .dataRefreshing: "arrow.clockwise.circle.fill"
        case .preferencesReset: "arrow.triangle.2.circlepath.circle.fill"
        case .appIconUnchanged: "exclamationmark.circle.fill"
        }
    }
}
