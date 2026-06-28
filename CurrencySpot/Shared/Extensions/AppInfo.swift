//
//  AppInfo.swift
//  CurrencySpot
//

import Foundation

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
