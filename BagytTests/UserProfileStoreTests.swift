import XCTest
@testable import Bagyt

final class UserProfileStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BagytTestSupport.resetDefaults()
    }

    override func tearDown() {
        BagytTestSupport.resetDefaults()
        super.tearDown()
    }

    func testNewUserStartsWithEmptyProfileAndDefaultGoals() {
        BagytTestSupport.setUser(BagytTestSupport.userA)

        let store = UserProfileStore.shared

        XCTAssertEqual(store.age, 0)
        XCTAssertEqual(store.weight, 0)
        XCTAssertEqual(store.height, 0)
        XCTAssertEqual(store.gender, "")
        XCTAssertEqual(store.goal, "")
        XCTAssertEqual(store.stepsGoal, 8000)
        XCTAssertEqual(store.waterGoal, 2.0, accuracy: 0.001)
        XCTAssertEqual(store.sleepGoal, 8.0, accuracy: 0.001)
        XCTAssertEqual(store.caloriesGoal, 2000)
    }

    func testProfileValuesAreScopedByUserToken() {
        BagytTestSupport.setUser(BagytTestSupport.userA)
        let store = UserProfileStore.shared
        store.age = 29
        store.weight = 74
        store.height = 181
        store.gender = "male"
        store.goal = "prevention"
        store.stepsGoal = 10_500
        store.waterGoal = 2.7
        store.sleepGoal = 7.5
        store.caloriesGoal = 2400
        store.save()

        BagytTestSupport.setUser(BagytTestSupport.userB)
        XCTAssertEqual(store.age, 0)
        XCTAssertEqual(store.gender, "")
        XCTAssertEqual(store.stepsGoal, 8000)
        XCTAssertEqual(store.waterGoal, 2.0, accuracy: 0.001)

        BagytTestSupport.setUser(BagytTestSupport.userA)
        XCTAssertEqual(store.age, 29)
        XCTAssertEqual(store.weight, 74, accuracy: 0.001)
        XCTAssertEqual(store.height, 181, accuracy: 0.001)
        XCTAssertEqual(store.gender, "male")
        XCTAssertEqual(store.goal, "prevention")
        XCTAssertEqual(store.stepsGoal, 10_500)
        XCTAssertEqual(store.waterGoal, 2.7, accuracy: 0.001)
        XCTAssertEqual(store.sleepGoal, 7.5, accuracy: 0.001)
        XCTAssertEqual(store.caloriesGoal, 2400)
    }

    func testResetForCurrentUserDoesNotEraseAnotherUser() {
        let store = UserProfileStore.shared

        BagytTestSupport.setUser(BagytTestSupport.userA)
        store.age = 35
        store.stepsGoal = 9000
        store.save()

        BagytTestSupport.setUser(BagytTestSupport.userB)
        store.age = 42
        store.stepsGoal = 6000
        store.save()
        store.resetForCurrentUser()

        XCTAssertEqual(store.age, 0)
        XCTAssertEqual(store.stepsGoal, 8000)

        BagytTestSupport.setUser(BagytTestSupport.userA)
        XCTAssertEqual(store.age, 35)
        XCTAssertEqual(store.stepsGoal, 9000)
    }

    func testBMIUpdatesFromHeightAndWeight() {
        BagytTestSupport.setUser(BagytTestSupport.userA)
        let store = UserProfileStore.shared
        store.height = 180
        store.weight = 81

        XCTAssertEqual(store.bmi, 25.0, accuracy: 0.01)

        store.height = 0
        XCTAssertEqual(store.bmi, 0, accuracy: 0.001)
    }

    func testSaveWritesScopedKeysForCurrentUser() {
        BagytTestSupport.setUser(BagytTestSupport.userA)
        let store = UserProfileStore.shared
        store.age = 21
        store.save()

        XCTAssertEqual(UserDefaults.standard.integer(forKey: "userAge_\(BagytTestSupport.userA)"), 21)
        XCTAssertNil(UserDefaults.standard.object(forKey: "userAge_\(BagytTestSupport.userB)"))
    }
}
