//
// Created by Michael Pace on 3/25/22.
//

import Foundation
import SwiftyBeaver


public protocol Loggable {
    func error(request: RequestMade)
}

public class SailsLogger: Loggable {
    private let logger = SwiftyBeaver.self
    private let console = ConsoleDestination()

    public init() {
        console.format = "$DHH:mm:ss$d $L $M"
        logger.addDestination(console)
    }

    public func error(request: RequestMade) {
        logger.error("Uh oh! Sails has received an unregistered \(request.method) request from \(request.uri)")
    }
}
