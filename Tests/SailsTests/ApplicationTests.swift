import Sails
import NIO
import NIOHTTP1
import AsyncHTTPClient
import XCTest
import Foundation


class SailsTests: XCTestCase {
  func test_requestsAreRoutedToCorrectHandler() {
    let app = Application()

    app.routes.get("/greeting") { _, _ in
      Response {
        Status.ok
        "hola"
      }
    }

    app.routes.get("/goodbye") { _, _ in
      Response {
        Status.ok
        "adieu"
      }
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    let response = try! client.get(url: "http://localhost:8080/greeting").wait()
    XCTAssertNotNil(response.body)
    var body = response.body!
    let greeting = body.readString(length: body.readableBytes)
    XCTAssertEqual(greeting, "hola")

    let goodbyeResponse = try! client.get(url: "http://localhost:8080/goodbye").wait()
    XCTAssertNotNil(goodbyeResponse.body)
    var goodbyeBody = goodbyeResponse.body!
    let goodbye = goodbyeBody.readString(length: goodbyeBody.readableBytes)
    XCTAssertEqual(goodbye, "adieu")

    try! channel.close().wait()
    try! client.syncShutdown()
  }

  func test_requestHandlersCanAccessTheRequestBody() {
    let app = Application()

    var tasks: [String?] = []
    app.routes.post("/tasks") { request, _ in
      var body = request.body!
      tasks.append(body.readString(length: body.readableBytes))

      return Response(status: .ok)
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    _ = try! client.post(url: "http://localhost:8080/tasks", body: .string("build a web framework")).wait()
    _ = try! client.post(url: "http://localhost:8080/tasks", body: .string("build a website")).wait()

    XCTAssertEqual(tasks, ["build a web framework", "build a website"])

    try! channel.close().wait()
    try! client.syncShutdown()
  }

  func test_requestHandlersCanAccessRequestHeaders() {
    let app = Application()

    var tokens: [String?] = []
    app.routes.post("/tasks") { request, _ in
      tokens.append(request.head.headers.first(name: "Authorization"))

      return Response(status: .ok)
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    let request = try! HTTPClient.Request(
      url: "http://localhost:8080/tasks",
      method: .POST,
      headers: ["Authorization": "token-1"],
      body: .string("body 1")
    )
    _ = try! client.execute(request: request).wait()

    XCTAssertEqual(tokens, ["token-1"])

    try! channel.close().wait()
    try! client.syncShutdown()
  }

  func test_requestHandlersCanReturnData() {
    let app = Application()

    app.routes.get("/greeting") { _, _ in
      Response {
        Status.ok
        "hello world".data(using: .utf8)!
      }
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    let response = try! client.get(url: "http://localhost:8080/greeting").wait()
    var body = response.body!
    let bodyString = body.readString(length: body.readableBytes)
    XCTAssertEqual(bodyString, "hello world")

    try! channel.close().wait()
    try! client.syncShutdown()
  }

  func test_requestHandlerCanReturnEncodable() {
    struct Task: Content, Encodable {
      let name: String
    }

    let app = Application()

    app.routes.get("/greeting") { _, _ in
      Response {
        Status.ok
        Task(name: "build something")
      }
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    let response = try! client.get(url: "http://localhost:8080/greeting").wait()

    var body = response.body!
    let bodyString = body.readString(length: body.readableBytes)

    let expectedBody = """
    {"name":"build something"}
    """
    XCTAssertEqual(bodyString, expectedBody)

    try! channel.close().wait()
    try! client.syncShutdown()
  }

  func test_requestHandlerCanSetResponseStatus() {
    let app = Application()

    app.routes.get("/greeting") { _, _ in
      Response(status: .notFound)
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    let response = try! client.get(url: "http://localhost:8080/greeting").wait()
    XCTAssertEqual(response.status, .notFound)

    try! channel.close().wait()
    try! client.syncShutdown()
  }

  func test_requestHandlerCanSpecifyHeaders() {
    let app = Application()

    app.routes.get("/greeting") { _, _ in
      Response(status: .notFound, headers: [("X-Greeting", ("Hello World"))], content: "Hello")
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    let response = try! client.get(url: "http://localhost:8080/greeting").wait()
    XCTAssertEqual(response.headers["X-Greeting"], ["Hello World"])

    try! channel.close().wait()
    try! client.syncShutdown()
  }

  func test_requestHandlerCanReturnPromise() {
    let app = Application()

    let sem = DispatchSemaphore(value: 0)
    var promise: EventLoopPromise<Response>?
    app.routes.get("/greeting") { _, eventLoop in
        promise = eventLoop.makePromise(of: Response.self)
        sem.signal()
        return promise!.futureResult
    }

    let channel = try! app.start().wait()
    let client = HTTPClient(eventLoopGroupProvider: .createNew)

    let responseFuture = client.get(url: "http://localhost:8080/greeting")
    let ex = self.expectation(description: "lol")
    responseFuture.whenSuccess { response in
        XCTAssertEqual(response.status, .ok)
        ex.fulfill()
    }

    sem.wait()
    promise?.succeed(Response(status: .ok, content: "lolololololol"))
    waitForExpectations(timeout: 1.0)

    try! channel.close().wait()
    try! client.syncShutdown()
  }

}
