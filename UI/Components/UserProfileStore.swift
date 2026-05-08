//
//  UserProfileStore.swift
//  Bagyt
//
//  Created by Жантемир Бериков on 23.04.2026.
//

import SwiftUI
import Combine

final class UserProfileStore: ObservableObject {

    static let shared = UserProfileStore()

    @Published var age          : Int    = 0
    @Published var weight       : Double = 0
    @Published var height       : Double = 0
    @Published var gender       : String = ""
    @Published var goal         : String = ""
    @Published var stepsGoal    : Int    = 8000
    @Published var waterGoal    : Double = 2.0
    @Published var sleepGoal    : Double = 8.0
    @Published var caloriesGoal : Int    = 2000

    private init() { load() }

    func load() {
        let ud = UserDefaults.standard
        resetValues()

        if hasScopedProfile(in: ud) {
            age          = ud.integer(forKey: scopedKey("userAge"))
            weight       = ud.double (forKey: scopedKey("userWeight"))
            height       = ud.double (forKey: scopedKey("userHeight"))
            gender       = ud.string (forKey: scopedKey("userGender")) ?? ""
            goal         = ud.string (forKey: scopedKey("userGoal"))   ?? ""
            stepsGoal    = ud.integer(forKey: scopedKey("stepsGoal"))    .nonZeroInt    ?? 8000
            waterGoal    = ud.double (forKey: scopedKey("waterGoal"))    .nonZeroDouble ?? 2.0
            sleepGoal    = ud.double (forKey: scopedKey("sleepGoal"))    .nonZeroDouble ?? 8.0
            caloriesGoal = ud.integer(forKey: scopedKey("caloriesGoal")) .nonZeroInt    ?? 2000
        }

        syncLegacyKeys()
    }

    func save() {
        saveScopedValues()
        syncLegacyKeys()
    }

    func resetForCurrentUser() {
        resetValues()
        saveScopedValues()
        syncLegacyKeys()
    }

    private var currentUserId: String {
        UserDefaults.standard.string(forKey: "userToken") ?? "guest"
    }

    private func scopedKey(_ key: String) -> String {
        "\(key)_\(currentUserId)"
    }

    private func hasScopedProfile(in ud: UserDefaults) -> Bool {
        let keys = [
            "userAge", "userWeight", "userHeight", "userBMI", "userGender", "userGoal",
            "stepsGoal", "waterGoal", "sleepGoal", "caloriesGoal"
        ]
        return keys.contains { ud.object(forKey: scopedKey($0)) != nil }
    }

    private func resetValues() {
        age          = 0
        weight       = 0
        height       = 0
        gender       = ""
        goal         = ""
        stepsGoal    = 8000
        waterGoal    = 2.0
        sleepGoal    = 8.0
        caloriesGoal = 2000
    }

    private func saveScopedValues() {
        saveValues { value, key in
            UserDefaults.standard.set(value, forKey: scopedKey(key))
        }
    }

    private func syncLegacyKeys() {
        saveValues { value, key in
            UserDefaults.standard.set(value, forKey: key)
        }
    }

    private func saveValues(_ save: (Any, String) -> Void) {
        save(age,          "userAge")
        save(weight,       "userWeight")
        save(height,       "userHeight")
        save(bmi,          "userBMI")
        save(gender,       "userGender")
        save(goal,         "userGoal")
        save(stepsGoal,    "stepsGoal")
        save(waterGoal,    "waterGoal")
        save(sleepGoal,    "sleepGoal")
        save(caloriesGoal, "caloriesGoal")
    }

    var genderLabel: String {
        switch gender {
        case "male":   return BagytL10n.tr("Мужской")
        case "female": return BagytL10n.tr("Женский")
        case "other":  return BagytL10n.tr("Другой")
        default:       return BagytL10n.tr("Не указано")
        }
    }

    var goalLabel: String {
        switch goal {
        case "chronic_disease": return BagytL10n.tr("Хронические болезни")
        case "prevention":      return BagytL10n.tr("Профилактика")
        case "stress_relief":   return BagytL10n.tr("Снижение стресса")
        case "weight_control":  return BagytL10n.tr("Контроль веса")
        default:                return BagytL10n.tr("Общее самочувствие")
        }
    }

    var bmi: Double {
        guard height > 0 else { return 0 }
        return weight / ((height / 100) * (height / 100))
    }

    var bmiLabel: String {
        switch bmi {
        case ..<18.5:   return BagytL10n.tr("Недовес")
        case 18.5..<25: return BagytL10n.tr("Норма")
        case 25..<30:   return BagytL10n.tr("Избыток")
        default:        return BagytL10n.tr("Ожирение")
        }
    }

    func bmiColor(accent: Color) -> Color {
        switch bmi {
        case ..<18.5:   return Color(red: 0.30, green: 0.60, blue: 0.95)
        case 18.5..<25: return Color(red: 0.10, green: 0.78, blue: 0.48)
        case 25..<30:   return Color(red: 1.00, green: 0.65, blue: 0.10)
        default:        return Color(red: 0.95, green: 0.25, blue: 0.25)
        }
    }
}

// MARK: - Helpers

private extension Int {
    var nonZeroInt: Int? { self == 0 ? nil : self }
}

private extension Double {
    var nonZeroDouble: Double? { self == 0.0 ? nil : self }
}
