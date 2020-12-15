enum RouteComponent: Equatable {
  case constant(String)
  case parameter(String)

  static func from(string: String) -> RouteComponent {
    if string.starts(with: ":") {
      return .parameter(String(string.dropFirst()))
    } else {
      return .constant(string)
    }
  }
}
