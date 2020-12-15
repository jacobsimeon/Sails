import XCTest
import Sails

final class HTTPMethodRouterTests: XCTestCase {

  func test_route_withEmptyRoutes_returnsNil() {
    let router = HTTPMethodRouter<String>()

    let result = router.route(.GET, uri: "/")
    XCTAssertNil(result.value)
    XCTAssertEqual(result.params, [:])
  }

  func test_route_withConstantNodes_returnsTheCorrectNode() {
    let router = HTTPMethodRouter<String>()

    router.add(.GET, uri: "/", value: "root")
    router.add(.GET, uri: "/hello/world", value: "HELLO")

    XCTAssertNil(router.route(.GET, uri: "").value)
    XCTAssertEqual(router.route(.GET, uri: "/").value, "root")
    XCTAssertEqual(router.route(.GET, uri: "/hello/world").value, "HELLO")
    XCTAssertNil(router.route(.GET, uri: "/hello").value)
  }

  func test_route_withParameterNode_returnsTheCorrectNode() {
    let router = HTTPMethodRouter<String>()

    router.add(.GET, uri: "/posts/:id", value: "GET A POST")
    router.add(.GET, uri: "/posts/mine", value: "MY POSTS")
    router.add(.GET, uri: "/posts/:id/comments", value: "THE COMMENTS")
    router.add(.GET, uri: "/stories/:story_id/tasks/:id", value: "A SINGLE TASK")

    var result = router.route(.GET, uri: "/posts")
    XCTAssertNil(result.value)
    XCTAssertEqual(result.params, [:])

    result = router.route(.GET, uri: "/posts/1")
    XCTAssertEqual(result.value, "GET A POST")
    XCTAssertEqual(result.params, ["id": "1"])

    result = router.route(.GET, uri: "/posts/mine")
    XCTAssertEqual(result.value, "MY POSTS")
    XCTAssertEqual(result.params, [:])

    result = router.route(.GET, uri: "/posts/1/comments")
    XCTAssertEqual(result.value, "THE COMMENTS")
    XCTAssertEqual(result.params, ["id": "1"])

    result = router.route(.GET, uri: "/stories/1/tasks/98")
    XCTAssertEqual(result.value, "A SINGLE TASK")
    XCTAssertEqual(result.params, ["story_id": "1", "id": "98"])

    result = router.route(.GET, uri: "/posts/1/comments/98/too-far")
    XCTAssertNil(result.value)
    XCTAssertEqual(result.params, [:])
  }

  func test_route_distinguishesBetweenHTTPMethod() {
    let router = HTTPMethodRouter<String>()

    router.add(.GET, uri: "/posts", value: "GET POSTS")
    router.add(.POST, uri: "/posts", value: "POST POSTS")

    XCTAssertEqual(router.route(.GET, uri: "/posts").value, "GET POSTS")
    XCTAssertEqual(router.route(.POST, uri: "/posts").value, "POST POSTS")
  }
}
