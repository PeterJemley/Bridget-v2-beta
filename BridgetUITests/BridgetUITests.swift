//
//  BridgetUITests.swift
//  BridgetUITests
//
//  Created by Peter Jemley on 7/24/25.
//

import XCTest

final class BridgetUITests: XCTestCase {

  override func setUpWithError() throws {
    continueAfterFailure = false
  }

  func testAppLaunch() throws {
    let app = XCUIApplication()
    app.launch()

    XCTAssertTrue(app.exists)
  }

  func testMainAppInterface() throws {
    let app = XCUIApplication()
    app.launch()

    let titleLabel = app.staticTexts["Bridget"]
    XCTAssertTrue(titleLabel.waitForExistence(timeout: 5), "App title should be visible")

    let subtitleLabel = app.staticTexts["Seattle Bridge Navigation"]
    XCTAssertTrue(subtitleLabel.exists, "App subtitle should be visible")
  }

  func testNavigationElements() throws {
    let app = XCUIApplication()
    app.launch()

    let findRouteText = app.staticTexts["Find Route"]
    XCTAssertTrue(findRouteText.waitForExistence(timeout: 5), "Find Route text should be visible")

    let bridgeStatusText = app.staticTexts["Bridge Status"]
    XCTAssertTrue(bridgeStatusText.exists, "Bridge Status text should be visible")

    let trafficAlertsText = app.staticTexts["Traffic Alerts"]
    XCTAssertTrue(trafficAlertsText.exists, "Traffic Alerts text should be visible")
  }

  func testFindRouteNavigation() throws {
    let app = XCUIApplication()
    app.launch()

    let findRouteText = app.staticTexts["Find Route"]
    XCTAssertTrue(findRouteText.waitForExistence(timeout: 5), "Find Route text should be visible")
    findRouteText.tap()

    XCTAssertTrue(app.exists, "App should remain responsive after navigation")
  }

  func testBridgeStatusNavigation() throws {
    let app = XCUIApplication()
    app.launch()

    let bridgeStatusText = app.staticTexts["Bridge Status"]
    XCTAssertTrue(bridgeStatusText.waitForExistence(timeout: 5), "Bridge Status text should be visible")
    bridgeStatusText.tap()

    XCTAssertTrue(app.exists, "App should remain responsive after navigation")
  }

  func testTrafficAlertsNavigation() throws {
    let app = XCUIApplication()
    app.launch()

    let trafficAlertsText = app.staticTexts["Traffic Alerts"]
    XCTAssertTrue(trafficAlertsText.waitForExistence(timeout: 5), "Traffic Alerts text should be visible")
    trafficAlertsText.tap()

    XCTAssertTrue(app.exists, "App should remain responsive after navigation")
  }

  func testAppAccessibility() throws {
    let app = XCUIApplication()
    app.launch()

    let titleLabel = app.staticTexts["Bridget"]
    XCTAssertTrue(titleLabel.waitForExistence(timeout: 5), "App title should be accessible")

    let findRouteText = app.staticTexts["Find Route"]
    XCTAssertTrue(findRouteText.exists, "Find Route text should be accessible")
  }

  func testLaunchPerformance() throws {
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      let app = XCUIApplication()
      app.launch()
    }
  }
}
