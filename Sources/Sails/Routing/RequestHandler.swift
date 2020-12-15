import NIOHTTP1
import NIO

public typealias RequestHandler = (Request, EventLoop) -> FutureResponse
