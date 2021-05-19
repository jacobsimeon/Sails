class RouterNode<ValueT> {
    var value: ValueT?
    private var constants: [String: RouterNode<ValueT>] = [:]
    private var parameter: ParameterNode<ValueT>?
    
    var isTerminal: Bool = false
    
    init(value: ValueT?) {
        self.value = value
    }
    
    func add(component: RouteComponent, value: ValueT) -> RouterNode<ValueT>{
        switch component {
        case .constant(let name):
            constants[name] = RouterNode(value: value)
            return constants[name]!
        case .parameter(let name):
            parameter = ParameterNode(name: name, innerNode: RouterNode(value: value))
            return parameter!.innerNode
        }
    }
    
    func child(component: String) -> (param: RouteParam?, node: RouterNode<ValueT>)? {
        if let constant = constants[component] {
            return (nil, constant)
        }
        
        if let parameter = parameter {
            return (RouteParam(name: parameter.name, value: component), parameter.innerNode)
        }
        
        return nil
    }
    
    func child(component: RouteComponent) -> RouterNode<ValueT>? {
        switch component {
        case .constant(let name):
            return constants[name]
        case .parameter:
            return parameter?.innerNode
        }
    }
}

private struct ParameterNode<ValueT> {
    let name: String
    let innerNode: RouterNode<ValueT>
    
    init(name: String, innerNode: RouterNode<ValueT>) {
        self.name = name
        self.innerNode = innerNode
    }
}
