import XCTest
@testable import Bagyt

final class LanguageManagerTests: XCTestCase {
    override func setUp() {
        super.setUp()
        BagytTestSupport.resetDefaults()
    }

    override func tearDown() {
        BagytTestSupport.resetDefaults()
        super.tearDown()
    }

    func testDefaultLanguageIsKazakh() {
        XCTAssertEqual(BagytL10n.currentLanguage, .kk)
    }

    func testChangingLanguagePersistsSelection() {
        UserDefaults.standard.set(AppLanguage.ru.rawValue, forKey: "language")

        XCTAssertEqual(UserDefaults.standard.string(forKey: "language"), "ru")
        XCTAssertEqual(BagytL10n.currentLanguage, .ru)
    }

    func testLanguageMetadataIsStable() {
        XCTAssertEqual(AppLanguage.kk.localeIdentifier, "kk")
        XCTAssertEqual(AppLanguage.ru.localeIdentifier, "ru")
        XCTAssertEqual(AppLanguage.en.localeIdentifier, "en")
        XCTAssertEqual(AppLanguage.ru.title, "Русский")
        XCTAssertEqual(AppLanguage.en.title, "English")
    }
}
