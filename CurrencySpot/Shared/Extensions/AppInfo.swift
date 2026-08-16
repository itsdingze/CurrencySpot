import Foundation

extension Bundle {
    var appName: String {
        infoDictionary?["CFBundleDisplayName"] as? String
            ?? infoDictionary?["CFBundleName"] as? String
            ?? "CurrencySpot"
    }

    var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var appVersionWithBuild: String {
        "\(appVersion) (\(buildNumber))"
    }
}
