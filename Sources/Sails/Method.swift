//
// Created by Michael Pace on 3/19/22.
//

import Foundation
import NIOHTTP1

public enum Method {
    case GET
    case POST

    init(rawValue: HTTPMethod) {
        switch rawValue {
        case HTTPMethod.GET: self = Method.GET
        case HTTPMethod.POST: self = Method.POST
        default: self = Method.GET
        }
    }
}

extension Method: CustomStringConvertible {
    public var description: String {
        switch self {
        case .GET: return "GET"
        case .POST: return "POST"
        }
    }
}