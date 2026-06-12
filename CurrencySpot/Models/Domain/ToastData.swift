//
//  ToastData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/4/25.
//

import Foundation

nonisolated enum ToastType: Sendable {
    case dataRefreshing, preferencesReset
}

nonisolated struct ToastData: Identifiable, Sendable {
    let id = UUID()
    let type: ToastType

    var message: String {
        switch type {
        case .dataRefreshing: "Refreshing Data"
        case .preferencesReset: "Settings Reset to Default"
        }
    }

    var icon: String {
        switch type {
        case .dataRefreshing: "arrow.clockwise.circle.fill"
        case .preferencesReset: "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}
