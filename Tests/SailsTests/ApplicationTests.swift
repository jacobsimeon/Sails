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

    func test_bigRequestBody() throws {
        let requestBody = """
        Vivamus sagittis lacus vel augue laoreet rutrum faucibus dolor auctor. Cras
        justo odio, dapibus ac facilisis in, egestas eget quam. Donec sed odio dui.
        Integer posuere erat a ante venenatis dapibus posuere velit aliquet. Integer
        posuere erat a ante venenatis dapibus posuere velit aliquet. Nulla vitae elit
        libero, a pharetra augue.

        Nullam id dolor id nibh ultricies vehicula ut id elit. Vivamus sagittis lacus
        vel augue laoreet rutrum faucibus dolor auctor. Vivamus sagittis lacus vel augue
        laoreet rutrum faucibus dolor auctor. Aenean eu leo quam. Pellentesque ornare
        sem lacinia quam venenatis vestibulum. Cras mattis consectetur purus sit amet
        fermentum.

        Donec sed odio dui. Nullam id dolor id nibh ultricies vehicula ut id elit. Lorem
        ipsum dolor sit amet, consectetur adipiscing elit. Nullam id dolor id nibh
        ultricies vehicula ut id elit. Duis mollis, est non commodo luctus, nisi erat
        porttitor ligula, eget lacinia odio sem nec elit. Aenean lacinia bibendum nulla
        sed consectetur. Donec id elit non mi porta gravida at eget metus.

        Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Donec sed odio
        dui. Vestibulum id ligula porta felis euismod semper. Donec sed odio dui. Donec
        sed odio dui. Maecenas sed diam eget risus varius blandit sit amet non magna.
        Integer posuere erat a ante venenatis dapibus posuere velit aliquet.

        Aenean eu leo quam. Pellentesque ornare sem lacinia quam venenatis vestibulum.
        Etiam porta sem malesuada magna mollis euismod. Vivamus sagittis lacus vel augue
        laoreet rutrum faucibus dolor auctor. Nulla vitae elit libero, a pharetra augue.
        Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Vestibulum id
        ligula porta felis euismod semper.

        Duis mollis, est non commodo luctus, nisi erat porttitor ligula, eget lacinia
        odio sem nec elit. Vivamus sagittis lacus vel augue laoreet rutrum faucibus
        dolor auctor. Sed posuere consectetur est at lobortis. Fusce dapibus, tellus ac
        cursus commodo, tortor mauris condimentum nibh, ut fermentum massa justo sit
        amet risus.

        Lorem ipsum dolor sit amet, consectetur adipiscing elit. Maecenas faucibus
        mollis interdum. Aenean lacinia bibendum nulla sed consectetur. Etiam porta sem
        malesuada magna mollis euismod. Nullam quis risus eget urna mollis ornare vel eu
        leo.

        Morbi leo risus, porta ac consectetur ac, vestibulum at eros. Maecenas faucibus
        mollis interdum. Cras mattis consectetur purus sit amet fermentum. Donec
        ullamcorper nulla non metus auctor fringilla. Cras mattis consectetur purus sit
        amet fermentum.
        """

        let app = Application()
        try app.start()

        let expectARequest = expectation(description: "A request")
        app.routes.post("/yo") { request, _ in
            defer {
                expectARequest.fulfill()
            }

            var body = request.body!
            let bodyString = body.readString(length: body.readableBytes)
            XCTAssertEqual(bodyString, requestBody)

            return Response {
                HTTPResponseStatus.ok
                "yo"
            }
        }

        let client = HTTPClient(eventLoopGroupProvider: .createNew)
        _ = client.post(
            url: "http://localhost:8080/yo",
            body: .string(requestBody)
        )

        wait(for: [expectARequest], timeout: 1)

        try app.stop()
        try client.syncShutdown()
    }
}
