//
//  FormatExtensions.swift
//  CurrencySpot
//
//  Created by Dingze Yu on 6/22/25.
//

import Foundation

// MARK: - Bundle Extensions

extension Bundle {
    /// Returns the user-facing app name from Info.plist
    var appName: String {
        infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "CurrencySpot"
    }

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
