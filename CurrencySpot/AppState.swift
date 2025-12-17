//
//  AppState.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 4/24/25.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class AppState {
    static let shared = AppState()

    private(set) var errorHandler = ErrorHandler()
    private(set) var networkMonitor = NetworkMonitor()

    private init() {}
}
