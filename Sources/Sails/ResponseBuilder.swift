@resultBuilder
public struct ResponseBuilder {
  public static func buildBlock(_ status: Status, _ content: Content) -> ResponseParts {
    return ResponseParts(status: status, headers: [], content: content)
  }
}
