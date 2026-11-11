import Foundation

extension Locale {
    nonisolated static func appLanguage(in shared: UserDefaults, system: Locale = .autoupdatingCurrent) -> Locale {
        guard let identifier = shared.string(forKey: UserDefaultsKeys.appLanguage) else { return system }
        var components = Locale.Components(locale: system)
        components.languageComponents = Locale.Language.Components(identifier: identifier)
        components.region = system.region
        return Locale(components: components)
    }
}

extension String {
    nonisolated init(localized resource: LocalizedStringResource, in locale: Locale) {
        var resource = resource
        resource.locale = locale
        self.init(localized: resource)
    }
}
