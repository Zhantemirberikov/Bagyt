import SwiftUI
import Combine
import Foundation

enum AppLanguage: String, CaseIterable {
    case kk = "kk"
    case ru = "ru"
    case en = "en"

    var flag: String {
        switch self {
        case .kk: return "🇰🇿"
        case .ru: return "🇷🇺"
        case .en: return "🇬🇧"
        }
    }

    var title: String {
        switch self {
        case .kk: return "Қазақша"
        case .ru: return "Русский"
        case .en: return "English"
        }
    }

    var localeIdentifier: String {
        switch self {
        case .kk: return "kk"
        case .ru: return "ru"
        case .en: return "en"
        }
    }
}

final class LanguageManager: ObservableObject {
    @Published var currentLanguage: AppLanguage

    init() {
        let savedLang = UserDefaults.standard.string(forKey: "language") ?? "kk"
        currentLanguage = AppLanguage(rawValue: savedLang) ?? .kk
    }

    func changeLanguage(to newLang: AppLanguage) {
        currentLanguage = newLang
        UserDefaults.standard.set(newLang.rawValue, forKey: "language")
    }

    func localized(_ key: String) -> String {
        BagytL10n.tr(key, language: currentLanguage)
    }
}

enum BagytL10n {
    static var currentLanguage: AppLanguage {
        AppLanguage(rawValue: UserDefaults.standard.string(forKey: "language") ?? "") ?? .kk
    }

    static var currentLocale: Locale {
        Locale(identifier: currentLanguage.localeIdentifier)
    }

    static func tr(_ key: String, language: AppLanguage? = nil) -> String {
        let selectedLanguage = language ?? currentLanguage

        guard let path = Bundle.main.path(forResource: selectedLanguage.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return key
        }

        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
}
