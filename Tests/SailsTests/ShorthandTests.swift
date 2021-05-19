import XCTest
import NIOHTTP1
import NIO
import Sails

class ResponseShorthandTests: XCTestCase {
    func test_shorthandForHTTPOneDotOne() {
        let response = Response(head: HTTPResponseHead(version: .oneDotOne, status: .ok), content: "")
        
        XCTAssertEqual(response.head.version, HTTPVersion(major: 1, minor: 1))
    }
    
    func test_initializingResponse_withStatus_buildsAResponseWithGivenStatus() {
        let response = Response(status: .ok)
        
        XCTAssertEqual(response.head.status, Status.ok)
        XCTAssertEqual(readContent(of: response), "")
    }
    
    func test_buildingResponse_withStatusAndContent_buildsResponseWithGivenStatusAndContent() {
        let response = Response {
            Status.notFound
            "hello world"
        }
        
        XCTAssertEqual(response.head.status, Status.notFound)
        XCTAssertEqual(readContent(of: response), "hello world")
    }
    
    func readContent(of response: Response) -> String? {
        var buffer = ByteBufferAllocator().buffer(capacity: 0)
        let length = try! response.content.encode(to: &buffer)
        return buffer.readString(length: length)
    }
}
