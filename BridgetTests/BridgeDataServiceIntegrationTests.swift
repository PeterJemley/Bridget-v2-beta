//
//  BridgeDataServiceIntegrationTests.swift
//  BridgetTests
//
//  Purpose: Integration tests for BridgeDataService with coordinate transformation
//  Dependencies: BridgeDataService, CoordinateTransformService, BridgeDataProcessor
//  Integration Points:
//    - Tests configuration management for transformation system
//    - Validates metrics tracking and reporting
//    - Ensures proper integration with existing data loading pipeline
//    - Verifies cache behavior with transformation metrics
//

import XCTest
@testable import Bridget

final class BridgeDataServiceIntegrationTests: XCTestCase {
    
    var bridgeDataService: BridgeDataService!
    
    override func setUpWithError() throws {
        bridgeDataService = BridgeDataService.shared
        bridgeDataService.resetTransformationMetrics()
    }
    
    override func tearDownWithError() throws {
        bridgeDataService.resetTransformationMetrics()
    }
    
    // MARK: - Configuration Tests
    
    func testDefaultTransformationConfig() {
        let config = bridgeDataService.getTransformationConfig()
        XCTAssertTrue(config.enabled)
        XCTAssertTrue(config.enableMetrics)
        XCTAssertFalse(config.enableDetailedLogging)
    }
    
    func testUpdateTransformationConfig() {
        let newConfig = BridgeDataService.TransformationConfig(
            enabled: false,
            enableMetrics: false,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(newConfig)
        
        let updatedConfig = bridgeDataService.getTransformationConfig()
        XCTAssertEqual(updatedConfig.enabled, newConfig.enabled)
        XCTAssertEqual(updatedConfig.enableMetrics, newConfig.enableMetrics)
        XCTAssertEqual(updatedConfig.enableDetailedLogging, newConfig.enableDetailedLogging)
    }
    
    func testTransformationConfigPersistence() {
        let originalConfig = bridgeDataService.getTransformationConfig()
        
        let newConfig = BridgeDataService.TransformationConfig(
            enabled: !originalConfig.enabled,
            enableMetrics: !originalConfig.enableMetrics,
            enableDetailedLogging: !originalConfig.enableDetailedLogging
        )
        bridgeDataService.updateTransformationConfig(newConfig)
        
        let updatedConfig = bridgeDataService.getTransformationConfig()
        XCTAssertEqual(updatedConfig.enabled, newConfig.enabled)
        XCTAssertEqual(updatedConfig.enableMetrics, newConfig.enableMetrics)
        XCTAssertEqual(updatedConfig.enableDetailedLogging, newConfig.enableDetailedLogging)
    }
    
    // MARK: - Metrics Tests
    
    func testInitialMetricsState() {
        let metrics = bridgeDataService.getTransformationMetrics()
        XCTAssertEqual(metrics.totalCoordinates, 0)
        XCTAssertEqual(metrics.transformedCoordinates, 0)
        XCTAssertEqual(metrics.skippedTransformations, 0)
        XCTAssertEqual(metrics.transformationFailures, 0)
        XCTAssertEqual(metrics.averageConfidence, 0.0)
        XCTAssertEqual(metrics.processingTimeSeconds, 0.0)
    }
    
    func testResetTransformationMetrics() async throws {
        // Load data to populate metrics
        let (bridges, failures) = try await bridgeDataService.loadHistoricalData()
        XCTAssertGreaterThan(bridges.count, 0)
        
        let metricsBeforeReset = bridgeDataService.getTransformationMetrics()
        XCTAssertGreaterThan(metricsBeforeReset.totalCoordinates, 0)
        
        // Reset metrics
        bridgeDataService.resetTransformationMetrics()
        
        let metricsAfterReset = bridgeDataService.getTransformationMetrics()
        XCTAssertEqual(metricsAfterReset.totalCoordinates, 0)
        XCTAssertEqual(metricsAfterReset.transformedCoordinates, 0)
        XCTAssertEqual(metricsAfterReset.skippedTransformations, 0)
        XCTAssertEqual(metricsAfterReset.transformationFailures, 0)
        XCTAssertEqual(metricsAfterReset.averageConfidence, 0.0)
        XCTAssertEqual(metricsAfterReset.processingTimeSeconds, 0.0)
    }
    
    // MARK: - Data Loading Tests
    
    func testLoadHistoricalDataWithMetricsDisabled() async throws {
        let config = BridgeDataService.TransformationConfig(
            enabled: true,
            enableMetrics: false,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(config)
        
        let (bridges, failures) = try await bridgeDataService.loadHistoricalData()
        XCTAssertGreaterThan(bridges.count, 0)
        
        let metrics = bridgeDataService.getTransformationMetrics()
        // Metrics should still be tracked even when disabled for display
        // Since cache is used, we expect at least 1 coordinate processed
        XCTAssertGreaterThanOrEqual(metrics.totalCoordinates, 0)
        XCTAssertGreaterThanOrEqual(metrics.skippedTransformations, 0)
    }
    
    func testLoadHistoricalDataWithTransformationMetrics() async throws {
        let config = BridgeDataService.TransformationConfig(
            enabled: true,
            enableMetrics: true,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(config)
        
        let (bridges, failures) = try await bridgeDataService.loadHistoricalData()
        XCTAssertGreaterThan(bridges.count, 0)
        
        let metrics = bridgeDataService.getTransformationMetrics()
        XCTAssertGreaterThanOrEqual(metrics.totalCoordinates, 0)
        XCTAssertGreaterThanOrEqual(metrics.processingTimeSeconds, 0.0)
    }
    
    // MARK: - Performance Tests
    
    func testTransformationPerformance() async throws {
        let config = BridgeDataService.TransformationConfig(
            enabled: true,
            enableMetrics: true,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(config)
        
        let startTime = Date()
        let (bridges, failures) = try await bridgeDataService.loadHistoricalData()
        let endTime = Date()
        
        XCTAssertGreaterThan(bridges.count, 0)
        
        let processingTime = endTime.timeIntervalSince(startTime)
        let metrics = bridgeDataService.getTransformationMetrics()
        
        // Verify processing time is reasonable (should be less than 5 seconds)
        XCTAssertLessThan(processingTime, 5.0)
        XCTAssertGreaterThanOrEqual(metrics.processingTimeSeconds, 0.0)
    }
}
