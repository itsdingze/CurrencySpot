//
//  AppExtensions.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 6/22/25.
//

import Foundation
import SwiftData
import SwiftUI

// MARK: - Bundle Extensions

extension Bundle {
    /// Returns the app version from Info.plist
    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    /// Returns the build number from Info.plist
    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    /// Returns formatted version string with build number
    var appVersionWithBuild: String {
        "\(appVersion) (\(buildNumber))"
    }
}

// MARK: - Color Extensions

extension Color {
    /// Primary text color that adapts to light/dark mode
    static let textPrimary = Color(UIColor.label)

    /// Secondary text color that adapts to light/dark mode
    static let textSecondary = Color(UIColor.secondaryLabel)
}

// MARK: - Date Extensions

extension Date {
    /// Format for chart display in local timezone
    var chartDisplay: String {
        TimeZoneManager.formatForChartDisplay(self)
    }
}
// MARK: - Double Extensions

extension Double {
    /// Convert to string with maximum 2 decimal places (0-2 range)
    var toStringMax2Decimals: String {
        formatted(.number.precision(.fractionLength(0 ... 2)))
    }

    /// Convert to string with maximum 4 decimal places (0-4 range)
    var toStringMax4Decimals: String {
        formatted(.number.precision(.fractionLength(0 ... 4)))
    }

    /// Convert to string with 2 decimal places
    var toString2Decimals: String {
        formatted(.number.precision(.fractionLength(2 ... 2)))
    }
}

// MARK: - View Extensions

extension View {
    /// Injects all ViewModels from DependencyContainer into the environment
    /// - Parameter container: The dependency container with all ViewModels
    /// - Returns: View with all ViewModels injected into environment
    func withDependencyContainer(_ container: DependencyContainer) -> some View {
        environment(container.calculatorViewModel)
            .environment(container.historyViewModel)
            .environment(container.settingsViewModel)
            .environment(container.cameraViewModel)
    }
}

// MARK: - DependencyContainer Extensions

extension DependencyContainer {
    /// Creates a preview-ready dependency container with in-memory storage
    /// - Returns: DependencyContainer configured for SwiftUI previews
    @MainActor
    static func preview() -> DependencyContainer {
        do {
            // Create in-memory model container for previews
            let configuration = ModelConfiguration(
                for: ExchangeRateData.self,
                HistoricalRateData.self,
                TrendData.self,
                isStoredInMemoryOnly: true
            )
            let previewContainer = try ModelContainer(
                for: ExchangeRateData.self,
                HistoricalRateData.self,
                TrendData.self,
                configurations: configuration
            )

            return try DependencyContainer(modelContainer: previewContainer)
        } catch {
            AppLogger.warning("Failed to create preview DependencyContainer: \(error)", category: .app)
            // Return a minimal container with mock service for previews
            return DependencyContainer(mockService: MockExchangeRateService())
        }
    }
}
