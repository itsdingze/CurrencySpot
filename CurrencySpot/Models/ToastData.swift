//
//  ToastData.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 5/4/25.
//

import Foundation

enum ToastType {
    case cacheCleared, preferencesReset
}

struct ToastData: Identifiable {
    let id = UUID()
    let type: ToastType

    var message: String {
        switch type {
        case .cacheCleared: "Cached Data Cleared"
        case .preferencesReset: "Settings Reset to Default"
        }
    }

    var icon: String {
        switch type {
        case .cacheCleared: "trash.circle.fill"
        case .preferencesReset: "arrow.triangle.2.circlepath.circle.fill"
        }
    }
}
