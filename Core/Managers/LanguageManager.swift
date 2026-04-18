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
}
