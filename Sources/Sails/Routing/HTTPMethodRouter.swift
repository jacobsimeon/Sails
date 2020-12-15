import NIOHTTP1

public class HTTPMethodRouter<ValueT> {
  private var routers: [HTTPMethod: Router<ValueT>]

  public init() {
    routers = [:]
  }

  public func add(_ method: HTTPMethod, uri: String, value: ValueT) {
    getOrAddRouter(for: method).add(uri: uri, value: value)
  }

  public func route(_ method: HTTPMethod, uri: String) -> RouteResult<ValueT> {
    return getOrAddRouter(for: method).route(uri: uri)
  }

  private func getOrAddRouter(for method: HTTPMethod) -> Router<ValueT> {
    if let router = routers[method] {
      return router
    }

    routers[method] = Router<ValueT>()
    return routers[method]!
  }
}
