//
// Created by Michael Pace on 3/25/22.
//

import NIO
import NIOHTTP1

class FunctionHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    typealias GetHandler = (HTTPRequestHead) -> RequestHandler?

    private var requestHead: HTTPRequestHead?
    private var requestBody: ByteBuffer?

    private let logger: Loggable
    private let getHandler: GetHandler

    init(logger: Loggable, getHandler: @escaping GetHandler) {
        self.logger = logger
        self.getHandler = getHandler
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let part = unwrapInboundIn(data)

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
                let uhOhResponse =  Response(
                        status: .notFound,
                        content: "Uh oh! Sails has received an unregistered \(head.method) head from \(head.uri)"
                )
                logger.error(request: RequestMade(method: Method.init(rawValue: head.method), uri: head.uri))
                send(uhOhResponse, via: context)
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

            let head = HTTPResponseHead(
                    version: HTTPVersion(major: 1, minor: 1),
                    status: response.head.status,
                    headers: headers
            )

            context.write(self.wrapOutboundOut(.head(head)), promise: nil)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)

            let keepAlive = self.requestHead?.isKeepAlive == true
            context.writeAndFlush(self.wrapOutboundOut(.end(nil))).whenComplete { _ in
                if !keepAlive {
                    context.close(promise: nil)
                }
            }
        }
    }
}