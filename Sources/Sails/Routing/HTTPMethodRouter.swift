import NIOHTTP1
import Foundation

public class HTTPMethodRouter<ValueT> {
    private var routers: [HTTPMethod: Router<ValueT>]
    
    public init() {
        routers = [:]
    }
    
    public func add(_ method: HTTPMethod, uri: String, value: ValueT) {
        getOrAddRouter(for: method).add(uri: uri, value: value)
    }
    
    public func route(_ method: HTTPMethod, uri: String) -> RouteResult<ValueT> {
        return getOrAddRouter(for: method).route(uri: removeQuery(from: uri))
    }
    
    private func getOrAddRouter(for method: HTTPMethod) -> Router<ValueT> {
        if let router = routers[method] {
            return router
        }

        let router = Router<ValueT>()
        defer { routers[method] = router }

        return router
    }

    private func removeQuery(from uri: String) -> String {
        guard let components = URLComponents(string: uri) else {
            return uri
        }

        return components.path
    }
}
