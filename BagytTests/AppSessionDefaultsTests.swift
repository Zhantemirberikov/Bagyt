import XCTest
@testable import Bagyt

final class AppSessionDefaultsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BagytTestSupport.resetDefaults()
    }

    override func tearDown() {
        BagytTestSupport.resetDefaults()
        super.tearDown()
    }

    func testNewInstallDefaultsToFirstLaunchAndLoggedOut() {
        XCTAssertNil(UserDefaults.standard.string(forKey: "userToken"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "userName"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "isLoggedIn"))
        XCTAssertNil(UserDefaults.standard.object(forKey: "isFirstLaunch"))
    }

    func testSavedSessionKeepsTokenNameAndLoginFlag() {
        UserDefaults.standard.set(BagytTestSupport.userA, forKey: "userToken")
        UserDefaults.standard.set("Kostya", forKey: "userName")
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
        UserDefaults.standard.set(false, forKey: "isFirstLaunch")

        XCTAssertEqual(UserDefaults.standard.string(forKey: "userToken"), BagytTestSupport.userA)
        XCTAssertEqual(UserDefaults.standard.string(forKey: "userName"), "Kostya")
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "isLoggedIn"))
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "isFirstLaunch"))
    }

    func testLogoutClearsOnlyActiveSessionKeys() {
        UserDefaults.standard.set(BagytTestSupport.userA, forKey: "userToken")
        UserDefaults.standard.set("Aruzhan", forKey: "userName")
        UserDefaults.standard.set("Aruzhan", forKey: "userName_\(BagytTestSupport.userA)")

        UserDefaults.standard.removeObject(forKey: "userToken")
        UserDefaults.standard.removeObject(forKey: "userName")

        XCTAssertNil(UserDefaults.standard.string(forKey: "userToken"))
        XCTAssertNil(UserDefaults.standard.string(forKey: "userName"))
        XCTAssertEqual(UserDefaults.standard.string(forKey: "userName_\(BagytTestSupport.userA)"), "Aruzhan")
    }
}
