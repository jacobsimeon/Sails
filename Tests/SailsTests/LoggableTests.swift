import Foundation
import XCTest
import AsyncHTTPClient

@testable import Sails

class LogableTests: XCTestCase {
    var subject: Application!

    var mockLogger: MockLogger!
    var client: HTTPClient!

    override func setUpWithError() throws {
        mockLogger = MockLogger()

        subject = Application(port: 8080, logger: mockLogger)
        client = HTTPClient(eventLoopGroupProvider: .createNew)

        try subject.start()
    }

    override func tearDownWithError() throws {
        try subject.stop()
        try client.syncShutdown()
    }

    func test_error_willExecuteForRequestsNotRegistered() throws {
        subject.routes.get("/greeting") { _, _ in
            Response(status: Status.ok, content: "hola")
        }
        subject.routes.post("/tasks") { request, _ in
            Response(status: .ok)
        }

        _ = try client.get(url: "http://localhost:8080/greeting").wait()
        _ = try client.post(url: "http://localhost:8080/tasks", body: .string("build a web framework")).wait()
        _ = try client.get(url: "http://localhost:8080/not_registered_1").wait()
        _ = try client.get(url: "http://localhost:8080/not_registered_2").wait()
        _ = try client.post(url: "http://localhost:8080/not_registered_3", body: .string("build a UI testing tool")).wait()

        XCTAssertTrue(mockLogger.lastRequestsErrored.contains(RequestMade(method: .GET, uri: "/not_registered_1")))
        XCTAssertTrue(mockLogger.lastRequestsErrored.contains(RequestMade(method: .GET, uri: "/not_registered_2")))
        XCTAssertTrue(mockLogger.lastRequestsErrored.contains(RequestMade(method: .POST, uri: "/not_registered_3")))
    }
}
