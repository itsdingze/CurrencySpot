//
//  AppState.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import Foundation
import SwiftUI

/// App-wide tab identity. Deep links target a tab by name, so the mapping
/// survives tabs being added, removed (camera on unsupported devices), or
/// ordered differently between the modern and legacy hierarchies.
enum AppTab: Hashable {
    case convert
    case camera
    case history
    case settings
}

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    private(set) var errorHandler = ErrorHandler()
    private(set) var networkMonitor = NetworkMonitor()

    /// App-wide tab selection, so features can deep-link into other tabs.
    var selectedTab = AppTab.convert

    /// Production code uses `shared`; tests create isolated instances so
    /// parallel runs can't clobber each other's state.
    init() {}
}
