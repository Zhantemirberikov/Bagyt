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
        let ud       = UserDefaults.standard
        age          = ud.integer(forKey: "userAge")
        weight       = ud.double (forKey: "userWeight")
        height       = ud.double (forKey: "userHeight")
        gender       = ud.string (forKey: "userGender")  ?? ""
        goal         = ud.string (forKey: "userGoal")    ?? ""
        stepsGoal    = ud.integer(forKey: "stepsGoal")    .nonZeroInt    ?? 8000
        waterGoal    = ud.double (forKey: "waterGoal")    .nonZeroDouble ?? 2.0
        sleepGoal    = ud.double (forKey: "sleepGoal")    .nonZeroDouble ?? 8.0
        caloriesGoal = ud.integer(forKey: "caloriesGoal") .nonZeroInt    ?? 2000
    }

    func save() {
        let ud = UserDefaults.standard
        ud.set(age,          forKey: "userAge")
        ud.set(weight,       forKey: "userWeight")
        ud.set(height,       forKey: "userHeight")
        ud.set(gender,       forKey: "userGender")
        ud.set(goal,         forKey: "userGoal")
        ud.set(stepsGoal,    forKey: "stepsGoal")
        ud.set(waterGoal,    forKey: "waterGoal")
        ud.set(sleepGoal,    forKey: "sleepGoal")
        ud.set(caloriesGoal, forKey: "caloriesGoal")
    }

    var genderLabel: String {
        switch gender {
        case "male":   return BagytL10n.tr("Мужской")
        case "female": return BagytL10n.tr("Женский")
        default:       return BagytL10n.tr("Другой")
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
