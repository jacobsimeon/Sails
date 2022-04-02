# ⛵️ Sails ⛵️

Sails is a lightweight, configurable mock server built to run alongside UI Tests for iOS and macOS applications - all
written in Swift.

## Usage
-----------------

Simply import Sails into your UI test, new up an `Application`, configure some endpoints, and start the server.

```swift
import Sails

let server = Application()
server.routes.post("/graphql") { request, _ in
    Response(status: .ok)
}
try server.start()
```

### Verifying Requests

Sails has the ability to determine whether a request was made to it. Let's look at the following example. Here we have 
a UI test that validates pull to refresh. You can also pass in the number of times you expect a request - by default, 
it will expect at least one call.

```swift
import XCTest
import Sails

class PullToRefreshTests: XCTestCase {
    var server: Application!
    var app: PocketAppElement!

    override func setUpWithError() throws {
        continueAfterFailure = false

        let uiApp = XCUIApplication()
        app = PocketAppElement(app: uiApp)
        
        // Configure Sails to respond to a POST /graphql with a 200 and no body
        server = Application()
        server.routes.post("/graphql") { request, _ in
            Response(status: .ok)
        }
        try server.start()

        app.launch()
    }

    override func tearDownWithError() throws {
        try server.stop()
        app.terminate()
    }

    func test_myList_pullToRefresh_fetchesNewContent() {
        app.tabBar.myListButton.wait().tap()

        let listView = app.myListView.wait()
        XCTAssertEqual(listView.itemCount, 2)

        // On the fly, update the response to POST /graphql with a 200 and body
        server.routes.post("/graphql") { _, _ in
            Response(status: .ok, content: "updated-list")
        }

        listView.pullToRefresh()

        listView.itemView(matching: "Updated Item 1").wait()
        listView.itemView(matching: "Updated Item 2").wait()
        
        // Verify a request was made
        server.verify(.POST, "/graphql")

        // Ensure that only one request was made to POST /graphql
//        XCTAssertEqual(server.verify(.POST, "/graphql"), 1)
    
        // Inversely, we can also ensure requests were not made
        XCTExpectFailure("Ensure following requests were not made") {
            subject.verify(Method.GET, "/greeting")
            subject.verify(Method.POST, "/task")
        }
    }
}
```

## Installation
-----------------

### Swift Package Manager

```
dependencies: [
    .package(url: "https://github.com/jacobsimeon/Sails", from: "1.0.0")
]
```

## Contributing
-----------------

Want to contribute to this repository? Check out [Contributing Guidelines](https://github.com/jacobsimeon/Sails/blob/main/CONTRIBUTING.md)

## License
-----------------

Sails is released under the [MIT License](LICENSE.md).