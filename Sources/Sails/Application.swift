import Foundation
import NIO
import NIOHTTP1
import NIOFoundationCompat

public class Application {
  public let routes = Routes()

  public init() {
    
  }

  public func start() -> EventLoopFuture<Channel> {
    let bootstrap = ServerBootstrap(group: MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount))
      .serverChannelOption(ChannelOptions.backlog, value: 256)
      .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
      .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline().flatMap { [weak self] in
          guard let app = self else {
            fatalError("Unable to add handler to pipeline because the application is no longer in memory")
          }

          return channel.pipeline.addHandler(app.handler())
        }
      }
      .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
      .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
      .childChannelOption(ChannelOptions.allowRemoteHalfClosure, value: true)

    return bootstrap.bind(host: "::1", port: 8080)
  }

  private func handler() -> FunctionHandler {
    return FunctionHandler() { [weak self] head in
      self?.routes.handler(for: head)
    }
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
    case .body(let buffer):
      requestBody = buffer
    case .end(_):

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
    response.response(on: context.eventLoop).whenSuccess { response in
      let contentLength = try! response.content.encode(to: &buffer)

      let head = HTTPServerResponsePart.head(
        HTTPResponseHead(
          version: HTTPVersion(major: 1, minor: 1),
          status: response.head.status,
          headers: ["Content-Length": "\(contentLength)"]
        )
      )

      _ = context.write(self.wrapOutboundOut(head))

      context.writeAndFlush(self.wrapOutboundOut(.body(.byteBuffer(buffer)))).whenComplete { (_) in
        _ = context.close()
      }
    }
  }
}
