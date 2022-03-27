import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat
import OSLog

public class Application {
    public let routes = Routes()
    private let port: Int

    private var group: EventLoopGroup?
    private var channel: Channel?
    private var bootstrap: ServerBootstrap?

    private var requestsMap: [RequestMade: Int] = [:]

    public init(port: Int = 8080) {
        self.port = port
    }

    public func stop() throws {
        try channel?.close().wait()
        try group?.syncShutdownGracefully()

        bootstrap = nil
        group = nil
        channel = nil
    }

    public func start() throws {
        group = MultiThreadedEventLoopGroup(numberOfThreads: 1)

        bootstrap = ServerBootstrap(group: group!)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline(withErrorHandling: true).flatMap { [weak self] in
                    guard let app = self else {
                        fatalError("Unable to add handler to pipeline because the application is no longer in memory")
                    }

                    return channel.pipeline.addHandler(app.handler())
                }
            }
            .childChannelOption(ChannelOptions.socket(IPPROTO_TCP, TCP_NODELAY), value: 1)
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)

        channel = try bootstrap?.bind(host: "::1", port: port).wait()
    }

    private func handler() -> FunctionHandler {
        return FunctionHandler() { [weak self] head in
            guard let self = self else {
                fatalError("Unable to add handler to pipeline because the application is no longer in memory")
            }

            self.requestsMap[RequestMade(method: Method.init(rawValue: head.method), uri: head.uri), default: 0] += 1

            return self.routes.handler(for: head)
        }
    }
}

extension Application: Verifier {
    public func verify(_ method: Method, _ uri: String) -> Int {
        requestsMap[RequestMade(method: method, uri: uri), default: 0]
    }
}

class FunctionHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    typealias GetHandler = (HTTPRequestHead) -> RequestHandler?

    private let getHandler: GetHandler
    private var requestHead: HTTPRequestHead?
    private var requestBody: ByteBuffer?

    init(getHandler: @escaping GetHandler) {
        self.getHandler = getHandler
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = self.unwrapInboundIn(data)

        switch part {
        case .head(let head):
            requestHead = head
            requestBody = nil
        case .body(var buffer):
            if requestBody == nil {
                requestBody = buffer
            } else {
                requestBody?.writeBuffer(&buffer)
            }
        case .end:
            guard let head = requestHead else {
                return
            }

            guard let handler = getHandler(head) else {
                return
            }

            let request = Request(head: head, body: requestBody)
            let response = handler(request, context.eventLoop)
            send(response, via: context)
        }
    }

    private func send(_ response: FutureResponse, via context: ChannelHandlerContext) {
        var buffer = context.channel.allocator.buffer(capacity: 0)
        response.response(on: context.eventLoop).whenSuccess { [weak self] response in
            guard let self = self else {
                return
            }

            let contentLength = try! response.content.encode(to: &buffer)

            var headers = response.head.headers
            headers.add(name: "Content-Length", value: String(contentLength))

            let head = HTTPServerResponsePart.head(
                HTTPResponseHead(
                    version: HTTPVersion(major: 1, minor: 1),
                    status: response.head.status,
                    headers: headers
                )
            )

            _ = context.write(self.wrapOutboundOut(head))

            context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer)))).whenComplete { (_) in
                _ = context.close()
            }
        }
    }
}
