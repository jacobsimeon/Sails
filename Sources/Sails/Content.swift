import NIO
import NIOHTTP1
import NIOFoundationCompat
import Foundation

public protocol Content {
    func encode(to buffer: inout ByteBuffer) throws -> Int
}

public struct NoContent: Content {
    public func encode(to buffer: inout ByteBuffer) throws -> Int {
        return 0
    }
}

extension String: Content {
    public func encode(to buffer: inout ByteBuffer) throws -> Int {
        buffer.writeString(self)
    }
}

extension Data: Content {
    public func encode(to buffer: inout ByteBuffer) throws -> Int {
        buffer.writeBytes(self)
    }
}

extension Content where Self: Encodable {
    public func encode(to buffer: inout ByteBuffer) throws -> Int {
        try buffer.writeJSONEncodable(self)
    }
}


