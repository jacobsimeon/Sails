import NIOHTTP1

public class Routes {
    public typealias RoutesBuilder = (Routes) -> ()
    private let router: HTTPMethodRouter = HTTPMethodRouter<RequestHandler>()
    
    public static func build(builder: RoutesBuilder) -> Routes {
        let routes = Routes()
        builder(routes)
        return routes
    }
    
    public func get(_ uri: String, handler: @escaping RequestHandler) {
        router.add(.GET, uri: uri, value: handler)
    }
    
    public func post(_ uri: String, handler: @escaping RequestHandler) {
        router.add(.POST, uri: uri, value: handler)
    }
    
    public func handler(for head: HTTPRequestHead) -> RequestHandler? {
        return router.route(head.method, uri: head.uri).value
    }
}
