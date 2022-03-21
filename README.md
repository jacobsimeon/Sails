# ⛵️ Sails ⛵️

Sails is a lightweight, configurable mock server built to run alongside UI Tests for iOS and macOS applications - all
written in Swift.

### Usage

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

Sails has the ability to determine whether or not a request was made to it. Let's look at the following example. Here
we have a UI test that validates pull to refresh.

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

        // Ensure that only one request was made to POST /graphql
        XCTAssertEqual(server.verify(.POST, "/graphql"), 1)
    }
}
```