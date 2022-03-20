//
// Created by Michael Pace on 3/19/22.
//

import Foundation
import NIOHTTP1

struct RequestMade {
    let method: Method
    let uri: String
}

extension RequestMade: Hashable {}