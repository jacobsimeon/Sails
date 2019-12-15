import XCTest
@testable import Sails

final class SailsTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(Sails().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
