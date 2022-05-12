import Foundation

import NIO
import NIOHTTP1

import XCTest

public class Application {
    public let routes = Routes()
    private var requestsMap: [RequestMade: Int] = [:]

    private var group: EventLoopGroup?
    private var channel: Channel?
    private var bootstrap: ServerBootstrap?

    private let port: Int
    private let logger: Loggable

    public init(port: Int = 8080, logger: Loggable = SailsLogger()) {
        self.port = port
        self.logger = logger
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
        FunctionHandler(logger: logger, getHandler: { [weak self] head in
            guard let self = self else {
                fatalError("Unable to add handler to pipeline because the application is no longer in memory")
            }

            let requestMade = RequestMade(method: Method.init(rawValue: head.method), uri: head.uri)
            self.requestsMap[requestMade, default: 0] += 1

            return self.routes.handler(for: head)
        })
    }
}

extension Application: Verifier {
    public func verify(_ method: Method, _ uri: String, times: UInt? = nil, file: StaticString = #filePath, line: UInt = #line) {
        let callCount = requestsMap[RequestMade(method: method, uri: uri), default: 0]
        if let times = times, times != callCount {
            XCTFail("Expected to receive request \(method) \(uri) \(times) times but it was sent \(callCount) times", file: file, line: line)
            return
        }

        if callCount < 1 {
            XCTFail("Unable to verify request \(method) \(uri)\t", file: file, line: line)
        }
    }
}
