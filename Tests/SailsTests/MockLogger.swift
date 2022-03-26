//
// Created by Michael Pace on 3/25/22.
//

@testable import Sails

class MockLogger: Loggable {
    var lastRequestsErrored = [RequestMade]()

    func error(request: RequestMade) {
        lastRequestsErrored.append(request)
    }
}

