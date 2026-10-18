import Foundation

extension Bundle {
    var appName: String {
        object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "CurrencySpot"
    }

    private var appVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    private var buildNumber: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    var appVersionWithBuild: String {
        "\(appVersion) (\(buildNumber))"
    }
}
