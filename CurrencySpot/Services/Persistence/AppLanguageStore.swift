protocol AppLanguageStore: AnyObject {
    var availableLanguages: [AppLanguage] { get }
    var selectedLanguage: AppLanguage { get set }
    var followsSystemLanguage: Bool { get }
    func resetToSystem()
}
