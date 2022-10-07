//
//  SDSScrollableTextViewExampleUITests.swift
//
//  Created by : Tomoaki Yagishita on 2022/10/07
//  © 2022  SmallDeskSoftware
//

import XCTest

final class SDSScrollableTextViewExampleUITests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.

        // In UI tests it is usually best to stop immediately when a failure occurs.
        continueAfterFailure = false

        // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    func test_reflect_fromTextView_toTextViewItselfAndTextEditor() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        let textView = app.textViews["SDSScrollableTextEditor"]
        let textEdit = app.textViews.allElementsBoundByIndex[1] // no way to identify TextEditor with accessibilityIdentifier.... :(
        textView.tap()
        textView.typeText("Hello")
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Input Hello"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(textView.value as? String, "Hello")
        XCTAssertEqual(textEdit.value as? String, "Hello")
    }

    func test_reflect_UnderlyingText_toTextView() throws {
        // UI tests must launch the application that they test.
        let app = XCUIApplication()
        app.launch()

        let textView = app.textViews["SDSScrollableTextEditor"]
        let textEdit = app.textViews.allElementsBoundByIndex[1] // no way to identify TextEditor with accessibilityIdentifier.... :(
        textEdit.tap()
        textEdit.typeText("Hello")
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "Input Hello in TextEditor then check TextView"
        attachment.lifetime = .keepAlways
        add(attachment)
        XCTAssertEqual(textView.value as? String, "Hello")
    }


//    func testLaunchPerformance() throws {
//        if #available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 7.0, *) {
//            // This measures how long it takes to launch your application.
//            measure(metrics: [XCTApplicationLaunchMetric()]) {
//                XCUIApplication().launch()
//            }
//        }
//    }
}
