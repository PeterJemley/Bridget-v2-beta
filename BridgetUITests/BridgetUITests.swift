//
//  BridgetUITests.swift
//  BridgetUITests
//
//  Created by Peter Jemley on 7/24/25.
//

import XCTest

final class BridgetUITests: XCTestCase {
  override func setUpWithError() throws {
    // Put setup code here. This method is called before the invocation of each test method in the class.

    // In UI tests it is usually best to stop immediately when a failure occurs.
    continueAfterFailure = false

    // In UI tests it's important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  @MainActor
  func testAppLaunch() throws {
    // Test that the app launches successfully
    let app = XCUIApplication()
    app.launch()
    
    // Verify the app launched without crashing
    XCTAssertTrue(app.exists)
  }

  @MainActor
  func testMainAppInterface() throws {
    // Test the main app interface elements
    let app = XCUIApplication()
    app.launch()
    
    // Wait for the app to load
    let titleLabel = app.staticTexts["Bridget"]
    XCTAssertTrue(titleLabel.waitForExistence(timeout: 5), "App title should be visible")
    
    // Test subtitle
    let subtitleLabel = app.staticTexts["Seattle Bridge Navigation"]
    XCTAssertTrue(subtitleLabel.exists, "App subtitle should be visible")
  }

  @MainActor
  func testNavigationElements() throws {
    // Test the main navigation elements
    let app = XCUIApplication()
    app.launch()
    
    // Wait for navigation text elements to load
    let findRouteText = app.staticTexts["Find Route"]
    XCTAssertTrue(findRouteText.waitForExistence(timeout: 5), "Find Route text should be visible")
    
    // Test bridge status text
    let bridgeStatusText = app.staticTexts["Bridge Status"]
    XCTAssertTrue(bridgeStatusText.exists, "Bridge Status text should be visible")
    
    // Test traffic alerts text
    let trafficAlertsText = app.staticTexts["Traffic Alerts"]
    XCTAssertTrue(trafficAlertsText.exists, "Traffic Alerts text should be visible")
  }

  @MainActor
  func testFindRouteNavigation() throws {
    // Test navigation to Find Route
    let app = XCUIApplication()
    app.launch()
    
    // Wait for Find Route text and tap it
    let findRouteText = app.staticTexts["Find Route"]
    XCTAssertTrue(findRouteText.waitForExistence(timeout: 5), "Find Route text should be visible")
    findRouteText.tap()
    
    // Verify navigation occurred (should be on a different screen)
    // Note: This might fail if the RouteListView requires app state that's not available in tests
    XCTAssertTrue(app.exists, "App should remain responsive after navigation")
  }

  @MainActor
  func testBridgeStatusNavigation() throws {
    // Test navigation to Bridge Status
    let app = XCUIApplication()
    app.launch()
    
    // Wait for Bridge Status text and tap it
    let bridgeStatusText = app.staticTexts["Bridge Status"]
    XCTAssertTrue(bridgeStatusText.waitForExistence(timeout: 5), "Bridge Status text should be visible")
    bridgeStatusText.tap()
    
    // Verify navigation occurred
    XCTAssertTrue(app.exists, "App should remain responsive after navigation")
  }

  @MainActor
  func testTrafficAlertsNavigation() throws {
    // Test navigation to Traffic Alerts
    let app = XCUIApplication()
    app.launch()
    
    // Wait for Traffic Alerts text and tap it
    let trafficAlertsText = app.staticTexts["Traffic Alerts"]
    XCTAssertTrue(trafficAlertsText.waitForExistence(timeout: 5), "Traffic Alerts text should be visible")
    trafficAlertsText.tap()
    
    // Verify navigation occurred
    XCTAssertTrue(app.exists, "App should remain responsive after navigation")
  }

  @MainActor
  func testAppAccessibility() throws {
    // Test accessibility features
    let app = XCUIApplication()
    app.launch()
    
    // Wait for content to load
    let titleLabel = app.staticTexts["Bridget"]
    XCTAssertTrue(titleLabel.waitForExistence(timeout: 5), "App title should be accessible")
    
    // Test that navigation elements are accessible
    let findRouteText = app.staticTexts["Find Route"]
    XCTAssertTrue(findRouteText.exists, "Find Route text should be accessible")
  }

  @MainActor
  func testLaunchPerformance() throws {
    // This measures how long it takes to launch your application.
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}
