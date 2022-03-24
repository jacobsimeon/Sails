//
// Created by Michael Pace on 3/19/22.
//

import Foundation

public protocol Verifier {
    func verify(_ method: Method, _ uri: String, times: UInt?, file: StaticString, line: UInt)
}