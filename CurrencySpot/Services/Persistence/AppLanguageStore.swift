protocol AppLanguageStore: AnyObject {
    var availableLanguages: [AppLanguage] { get }
    var selectedLanguage: AppLanguage { get set }
    func resetToSystem()
}
