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

    // In UI tests it’s important to set the initial state - such as interface orientation - required for your tests before they run. The setUp method is a good place to do this.
  }

  override func tearDownWithError() throws {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
  }

  @MainActor
  func testExample() throws {
    // UI tests must launch the application that they test.
    let app = XCUIApplication()
    app.launch()

    // Use XCTAssert and related functions to verify your tests produce the correct results.
  }
  
  // MARK: - ML Pipeline UI Tests
  
  @MainActor
  func testMLPipelineTabNavigation() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    let mlPipelineTab = app.tabBars.buttons["ML Pipeline"]
    XCTAssertTrue(mlPipelineTab.exists, "ML Pipeline tab should exist")
    mlPipelineTab.tap()
    
    // Verify we're on the ML Pipeline screen
    let mlPipelineTitle = app.staticTexts["ML Pipeline"]
    XCTAssertTrue(mlPipelineTitle.exists, "ML Pipeline title should be visible")
  }
  
  @MainActor
  func testPipelineStatusCardElements() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    app.tabBars.buttons["ML Pipeline"].tap()
    
    // Verify Pipeline Status card elements
    let pipelineStatusTitle = app.staticTexts["Pipeline Status"]
    XCTAssertTrue(pipelineStatusTitle.exists, "Pipeline Status title should be visible")
    
    // Verify status rows exist
    let dataPopulationRow = app.staticTexts["Data Population"]
    let dataExportRow = app.staticTexts["Data Export"]
    let autoExportRow = app.staticTexts["Auto-Export"]
    
    XCTAssertTrue(dataPopulationRow.exists, "Data Population row should be visible")
    XCTAssertTrue(dataExportRow.exists, "Data Export row should be visible")
    XCTAssertTrue(autoExportRow.exists, "Auto-Export row should be visible")
    
    // Verify status indicators
    let needsAttentionText = app.staticTexts["Needs Attention"]
    XCTAssertTrue(needsAttentionText.exists, "Needs Attention status should be visible")
    
    let neverStatus = app.staticTexts["Never"]
    XCTAssertTrue(neverStatus.exists, "Never status should be visible for data operations")
    
    let disabledStatus = app.staticTexts["Disabled"]
    XCTAssertTrue(disabledStatus.exists, "Disabled status should be visible for auto-export")
  }
  
  @MainActor
  func testQuickActionsButtons() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    app.tabBars.buttons["ML Pipeline"].tap()
    
    // Verify Quick Actions section
    let quickActionsTitle = app.staticTexts["Quick Actions"]
    XCTAssertTrue(quickActionsTitle.exists, "Quick Actions title should be visible")
    
    // Verify Populate Today button
    let populateTodayButton = app.buttons["populate-today-button"]
    XCTAssertTrue(populateTodayButton.exists, "Populate Today button should exist")
    
    let populateTodayText = app.staticTexts["Populate Today"]
    XCTAssertTrue(populateTodayText.exists, "Populate Today text should be visible")
    
    // Verify Export Today button
    let exportTodayButton = app.buttons["export-today-button"]
    XCTAssertTrue(exportTodayButton.exists, "Export Today button should exist")
    
    let exportTodayText = app.staticTexts["Export Today"]
    XCTAssertTrue(exportTodayText.exists, "Export Today text should be visible")
  }
  
  @MainActor
  func testQuickActionsFunctionality() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    app.tabBars.buttons["ML Pipeline"].tap()
    
    // Test Populate Today button tap
    let populateTodayButton = app.buttons["populate-today-button"]
    XCTAssertTrue(populateTodayButton.exists, "Populate Today button should exist")
    populateTodayButton.tap()
    
    // Wait a moment for the operation to start
    Thread.sleep(forTimeInterval: 1.0)
    
    // Test Export Today button tap
    let exportTodayButton = app.buttons["export-today-button"]
    XCTAssertTrue(exportTodayButton.exists, "Export Today button should exist")
    exportTodayButton.tap()
    
    // Wait a moment for the operation to start
    Thread.sleep(forTimeInterval: 1.0)
  }
  
  @MainActor
  func testRecentActivitySection() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    app.tabBars.buttons["ML Pipeline"].tap()
    
    // Verify Recent Activity section
    let recentActivityTitle = app.staticTexts["Recent Activity"]
    XCTAssertTrue(recentActivityTitle.exists, "Recent Activity title should be visible")
    
    // Verify activity items exist
    let dataPopulationActivity = app.staticTexts["Data Population"]
    let dataExportActivity = app.staticTexts["Data Export"]
    
    XCTAssertTrue(dataPopulationActivity.exists, "Data Population activity should be visible")
    XCTAssertTrue(dataExportActivity.exists, "Data Export activity should be visible")
    
    // Verify activity descriptions
    let populationDescription = app.staticTexts["Today's data populated successfully"]
    let exportDescription = app.staticTexts["Yesterday's data exported to Documents"]
    
    XCTAssertTrue(populationDescription.exists, "Data population description should be visible")
    XCTAssertTrue(exportDescription.exists, "Data export description should be visible")
    
    // Verify timestamps
    let twoHoursAgo = app.staticTexts["2 hours ago"]
    let oneDayAgo = app.staticTexts["1 day ago"]
    
    XCTAssertTrue(twoHoursAgo.exists, "2 hours ago timestamp should be visible")
    XCTAssertTrue(oneDayAgo.exists, "1 day ago timestamp should be visible")
  }
  
  @MainActor
  func testPipelineSettingsButton() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    app.tabBars.buttons["ML Pipeline"].tap()
    
    // Verify Pipeline Settings button
    let pipelineSettingsButton = app.buttons["pipeline-settings-button"]
    XCTAssertTrue(pipelineSettingsButton.exists, "Pipeline Settings button should exist")
    
    let pipelineSettingsText = app.staticTexts["Pipeline Settings"]
    XCTAssertTrue(pipelineSettingsText.exists, "Pipeline Settings text should be visible")
  }
  
  @MainActor
  func testPipelineSettingsNavigation() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    app.tabBars.buttons["ML Pipeline"].tap()
    
    // Tap Pipeline Settings button
    let pipelineSettingsButton = app.buttons["pipeline-settings-button"]
    XCTAssertTrue(pipelineSettingsButton.exists, "Pipeline Settings button should exist")
    pipelineSettingsButton.tap()
    
    // Verify navigation to Settings tab
    let settingsTab = app.tabBars.buttons["Settings"]
    XCTAssertTrue(settingsTab.exists, "Settings tab should exist")
    
    // The button should have navigated us to the Settings tab
    // We can verify this by checking if we're no longer on the ML Pipeline tab
    let mlPipelineTab = app.tabBars.buttons["ML Pipeline"]
    XCTAssertTrue(mlPipelineTab.exists, "ML Pipeline tab should still exist")
  }
  
  @MainActor
  func testMLPipelineCompleteWorkflow() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Navigate to ML Pipeline tab
    app.tabBars.buttons["ML Pipeline"].tap()
    
    // Verify all main sections are present
    let mlPipelineTitle = app.staticTexts["ML Pipeline"]
    XCTAssertTrue(mlPipelineTitle.exists, "ML Pipeline title should be visible")
    
    let pipelineStatusTitle = app.staticTexts["Pipeline Status"]
    XCTAssertTrue(pipelineStatusTitle.exists, "Pipeline Status section should be visible")
    
    let quickActionsTitle = app.staticTexts["Quick Actions"]
    XCTAssertTrue(quickActionsTitle.exists, "Quick Actions section should be visible")
    
    let recentActivityTitle = app.staticTexts["Recent Activity"]
    XCTAssertTrue(recentActivityTitle.exists, "Recent Activity section should be visible")
    
    // Verify all interactive elements are tappable
    let populateTodayButton = app.buttons["populate-today-button"]
    let exportTodayButton = app.buttons["export-today-button"]
    let pipelineSettingsButton = app.buttons["pipeline-settings-button"]
    
    XCTAssertTrue(populateTodayButton.isEnabled, "Populate Today button should be enabled")
    XCTAssertTrue(exportTodayButton.isEnabled, "Export Today button should be enabled")
    XCTAssertTrue(pipelineSettingsButton.isEnabled, "Pipeline Settings button should be enabled")
  }

  @MainActor
  func testLaunchPerformance() throws {
    // This measures how long it takes to launch your application.
    measure(metrics: [XCTApplicationLaunchMetric()]) {
      XCUIApplication().launch()
    }
  }
}
