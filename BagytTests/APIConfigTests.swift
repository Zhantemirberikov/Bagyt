import XCTest
@testable import Bagyt

final class APIConfigTests: XCTestCase {
    func testBaseURLUsesHTTPS() {
        XCTAssertEqual(APIConfig.baseURL.scheme, "https")
    }

    func testURLBuilderTrimsLeadingSlash() {
        XCTAssertEqual(APIConfig.url("profile").absoluteString, APIConfig.baseURL.appendingPathComponent("profile").absoluteString)
        XCTAssertEqual(APIConfig.url("/profile").absoluteString, APIConfig.baseURL.appendingPathComponent("profile").absoluteString)
    }

    func testURLBuilderPreservesNestedPath() {
        XCTAssertEqual(
            APIConfig.url("health/metrics").absoluteString,
            APIConfig.baseURL.appendingPathComponent("health/metrics").absoluteString
        )
    }
}
