class Router<ValueType> {
    private let root: RouterNode<ValueType>
    
    init() {
        root = RouterNode<ValueType>(value: nil)
    }
    
    public func add(uri: String, value: ValueType) {
        if uri == "/" {
            root.value = value
            return
        }
        
        let components = uri.split(separator: "/").map(String.init).map(RouteComponent.from)
        add(components: components, value: value)
    }
    
    public func route(uri: String) -> RouteResult<ValueType> {
        if uri == "/" {
            return RouteResult(value: root.value, params: [:])
        }
        
        return route(components: uri.split(separator: "/").map(String.init))
    }
    
    private func add(components: [RouteComponent], value: ValueType) {
        var currentNode = root
        for component in components {
            if let child = currentNode.child(component: component) {
                currentNode = child
            } else {
                currentNode = currentNode.add(component: component, value: value)
            }
            
            if component == components.last {
                currentNode.isTerminal = true
            }
        }
    }
    
    private func route(components: [String]) -> RouteResult<ValueType> {
        guard !components.isEmpty else {
            return RouteResult<ValueType>(value: nil, params: [:])
        }
        
        var params: [String: String] = [:]
        var currentNode = root
        var currentIndex = 0
        while currentIndex < components.count,
              let child = currentNode.child(component: components[currentIndex]) {
            
            if let param = child.param {
                params[param.name] = param.value
            }
            
            currentIndex += 1
            currentNode = child.node
        }
        
        if currentIndex == components.count, currentNode.isTerminal {
            return RouteResult(value: currentNode.value, params: params)
        }
        
        return RouteResult<ValueType>(value: nil, params: [:])
    }
    
}
