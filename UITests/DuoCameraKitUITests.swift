import XCTest

final class DuoCameraKitUITests: XCTestCase {
    
    override func setUpWithError() throws {
        continueAfterFailure = false
    }
    
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "nohinge"]
        app.launch()
        
        XCTAssertTrue(app.staticTexts["Duo Camera Kit"].exists)
    }
    
    func testLensModeLaunchWithFoldMock() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-UITestMode", "1", "-FoldMock", "half:110"]
        app.launch()
        
        XCTAssertTrue(app.staticTexts["Duo Camera Kit"].exists)
    }
}
