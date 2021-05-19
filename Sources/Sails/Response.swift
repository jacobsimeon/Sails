import NIO
import NIOHTTP1
import Foundation

public typealias Status = HTTPResponseStatus

public protocol FutureResponse {
    func response(on eventLoop: EventLoop) -> EventLoopFuture<Response>
}

public struct Header {
    let name: String
    let value: String
}

public struct ResponseParts {
    let status: Status
    let headers: [(String, String)]
    let content: Content
}

public struct Response {
    public let head: HTTPResponseHead
    public let content: Content
    
    public init(head: HTTPResponseHead, content: Content) {
        self.head = head
        self.content = content
    }
    
    public init(status: Status) {
        self.init(status: status, content: NoContent())
    }
    
    public init(status: Status, content: Content) {
        self.init(status: status, headers: [], content: content)
    }
    
    public init(status: Status, headers: [(String, String)], content: Content) {
        self.init(
            head: HTTPResponseHead(
                version: .oneDotOne,
                status: status,
                headers: HTTPHeaders(headers)
            ),
            content: content
        )
    }
    
    public init(@ResponseBuilder _ builder: () -> ResponseParts) {
        let parts = builder()
        
        self.init(status: parts.status, headers: parts.headers, content: parts.content)
    }
}

extension Response: FutureResponse {
    public func response(on eventLoop: EventLoop) -> EventLoopFuture<Response> {
        eventLoop.makeSucceededFuture(self)
    }
}

extension EventLoopFuture: FutureResponse where Value == Response {
    public func response(on eventLoop: EventLoop) -> EventLoopFuture<Response> {
        return self
    }
}
