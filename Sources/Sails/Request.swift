import NIOHTTP1
import NIO

public struct Request {
    public let head: HTTPRequestHead
    public let body: ByteBuffer?
}
