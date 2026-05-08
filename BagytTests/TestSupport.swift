import XCTest
@testable import Bagyt

enum BagytTestSupport {
    static let userA = "test-token-alpha"
    static let userB = "test-token-beta"

    static func resetDefaults() {
        let defaults = UserDefaults.standard
        let prefixes = [
            "bagyt_",
            "chat_history_",
            "active_chat_id_",
            "hasCompletedProfileOnboarding_",
            "userName_",
            "userAvatar_",
            "userAge",
            "userWeight",
            "userHeight",
            "userBMI",
            "userGender",
            "userGoal",
            "stepsGoal",
            "waterGoal",
            "sleepGoal",
            "caloriesGoal"
        ]
        let exactKeys = [
            "userToken",
            "userName",
            "userId",
            "isLoggedIn",
            "isFirstLaunch",
            "language"
        ]

        for key in defaults.dictionaryRepresentation().keys {
            if exactKeys.contains(key) || prefixes.contains(where: { key.hasPrefix($0) }) {
                defaults.removeObject(forKey: key)
            }
        }

        UserProfileStore.shared.load()
    }

    static func setUser(_ token: String) {
        UserDefaults.standard.set(token, forKey: "userToken")
        UserProfileStore.shared.load()
    }
}
