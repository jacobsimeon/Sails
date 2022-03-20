import Foundation
import XCTest
import AsyncHTTPClient

@testable import Sails

class VerifierTests: XCTestCase {
    var subject: Application!

    var client: HTTPClient!

    override func setUpWithError() throws {
        subject = Application()
        client = HTTPClient(eventLoopGroupProvider: .createNew)

        try subject.start()
    }

    override func tearDownWithError() throws {
        try subject.stop()
        try client.syncShutdown()
    }

    func test_verify__noRequestsHaveBeenMade__returnZero() throws {
        subject.routes.get("/greeting") { _, _ in
            Response(status: Status.ok, content: "hola")
        }
        subject.routes.post("/tasks") { _, _ in
            Response(status: .ok)
        }

        XCTAssertEqual(subject.verify(Method.GET, "/greeting"), 0)
        XCTAssertEqual(subject.verify(Method.POST, "/task"), 0)
    }

    func test_verify__requestsHaveBeenMade__verifierReturnsNumberOfCalls() throws {
        subject.routes.get("/greeting") { _, _ in
            Response(status: Status.ok, content: "hola")
        }
        subject.routes.post("/tasks") { request, _ in
            Response(status: .ok)
        }

        _ = try client.get(url: "http://localhost:8080/greeting").wait()
        _ = try client.post(url: "http://localhost:8080/tasks", body: .string("build a web framework")).wait()
        _ = try client.get(url: "http://localhost:8080/greeting").wait()

        XCTAssertEqual(subject.verify(Method.GET, "/greeting"), 2)
        XCTAssertEqual(subject.verify(Method.POST, "/tasks"), 1)
    }
}