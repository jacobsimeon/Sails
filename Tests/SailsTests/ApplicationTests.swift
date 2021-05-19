import Sails
import NIO
import NIOHTTP1
import AsyncHTTPClient
import XCTest
import Foundation


class SailsTests: XCTestCase {
    func test_requestsAreRoutedToCorrectHandler() throws {
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
        
        try app.start()
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        
        let response = try client.get(url: "http://localhost:8080/greeting").wait()
        XCTAssertNotNil(response.body)
        var body = response.body!
        let greeting = body.readString(length: body.readableBytes)
        XCTAssertEqual(greeting, "hola")
        
        let goodbyeResponse = try client.get(url: "http://localhost:8080/goodbye").wait()
        XCTAssertNotNil(goodbyeResponse.body)
        var goodbyeBody = goodbyeResponse.body!
        let goodbye = goodbyeBody.readString(length: goodbyeBody.readableBytes)
        XCTAssertEqual(goodbye, "adieu")

        try app.stop()
        try client.syncShutdown()
    }
    
    func test_requestHandlersCanAccessTheRequestBody() throws {
        let app = Application()
        
        var tasks: [String?] = []
        app.routes.post("/tasks") { request, _ in
            var body = request.body!
            tasks.append(body.readString(length: body.readableBytes))
            
            return Response(status: .ok)
        }
        
        try app.start()
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        
        _ = try client.post(url: "http://localhost:8080/tasks", body: .string("build a web framework")).wait()
        _ = try client.post(url: "http://localhost:8080/tasks", body: .string("build a website")).wait()
        
        XCTAssertEqual(tasks, ["build a web framework", "build a website"])
        
        try app.stop()
        try client.syncShutdown()
    }
    
    func test_requestHandlersCanAccessRequestHeaders() throws {
        let app = Application()
        
        var tokens: [String?] = []
        app.routes.post("/tasks") { request, _ in
            tokens.append(request.head.headers.first(name: "Authorization"))
            
            return Response(status: .ok)
        }
        
        try app.start()
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        
        let request = try HTTPClient.Request(
            url: "http://localhost:8080/tasks",
            method: .POST,
            headers: ["Authorization": "token-1"],
            body: .string("body 1")
        )
        _ = try client.execute(request: request).wait()
        
        XCTAssertEqual(tokens, ["token-1"])
        
        try app.stop()
        try client.syncShutdown()
    }
    
    func test_requestHandlersCanReturnData() throws {
        let app = Application()
        
        app.routes.get("/greeting") { _, _ in
            Response {
                Status.ok
                "hello world".data(using: .utf8)!
            }
        }
        
        try app.start()
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        
        let response = try client.get(url: "http://localhost:8080/greeting").wait()
        var body = response.body!
        let bodyString = body.readString(length: body.readableBytes)
        XCTAssertEqual(bodyString, "hello world")
        
        try app.stop()
        try client.syncShutdown()
    }
    
    func test_requestHandlerCanReturnEncodable() throws {
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

        try app.start()
        let client = HTTPClient(eventLoopGroupProvider: .createNew)

        let response = try client.get(url: "http://localhost:8080/greeting").wait()

        var body = response.body!
        let bodyString = body.readString(length: body.readableBytes)

        let expectedBody = """
        {"name":"build something"}
        """
        XCTAssertEqual(bodyString, expectedBody)
        
        try app.stop()
        try client.syncShutdown()
    }
    
    func test_requestHandlerCanSetResponseStatus() throws {
        let app = Application()
        
        app.routes.get("/greeting") { _, _ in
            Response(status: .notFound)
        }
        
        try app.start()
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        
        let response = try client.get(url: "http://localhost:8080/greeting").wait()
        XCTAssertEqual(response.status, .notFound)
        
        try app.stop()
        try client.syncShutdown()
    }
    
    func test_requestHandlerCanSpecifyHeaders() throws {
        let app = Application()
        
        app.routes.get("/greeting") { _, _ in
            Response(status: .notFound, headers: [("X-Greeting", ("Hello World"))], content: "Hello")
        }
        
        try app.start()
        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        
        let response = try client.get(url: "http://localhost:8080/greeting").wait()
        XCTAssertEqual(response.headers["X-Greeting"], ["Hello World"])
        
        try app.stop()
        try client.syncShutdown()
    }
    
    func test_requestHandlerCanReturnPromise() throws {
        let app = Application()
        
        var promise: EventLoopPromise<Response>?
        app.routes.get("/greeting") { _, eventLoop in
            promise = eventLoop.makePromise(of: Response.self)
            return promise!.futureResult
        }
        
        try app.start()

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        let responseFuture = client.get(url: "http://localhost:8080/greeting")

        let ex = expectation(description: "waiting for response")
        responseFuture.whenSuccess { response in
            XCTAssertEqual(response.status, .ok)
            var body = response.body!
            XCTAssertEqual(body.readString(length: body.readableBytes), "lolololololol")
            ex.fulfill()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            promise?.succeed(Response(status: .ok, content: "lolololololol"))
        }

        waitForExpectations(timeout: 3.0)
        
        try app.stop()
        try client.syncShutdown()
    }
}
