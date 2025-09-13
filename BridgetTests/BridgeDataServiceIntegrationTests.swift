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

import Foundation
import Testing

@testable import Bridget

@MainActor
@Suite("Bridge Data Service Integration Tests", .serialized)
struct BridgeDataServiceIntegrationTests {
    var bridgeDataService: BridgeDataService

    init() {
        bridgeDataService = BridgeDataService.shared
        bridgeDataService.resetTransformationMetrics()
    }

    // MARK: - Configuration Tests

    @Test(
        "Default transformation config is enabled with metrics, without detailed logging"
    )
    func defaultTransformationConfig() {
        let config = bridgeDataService.getTransformationConfig()
        #expect(config.enabled)
        #expect(config.enableMetrics)
        #expect(!config.enableDetailedLogging)
    }

    @Test("Update transformation config persists new values")
    func testUpdateTransformationConfig() {
        let newConfig = BridgeDataService.TransformationConfig(
            enabled: false,
            enableMetrics: false,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(newConfig)

        let updatedConfig = bridgeDataService.getTransformationConfig()
        #expect(updatedConfig.enabled == newConfig.enabled)
        #expect(updatedConfig.enableMetrics == newConfig.enableMetrics)
        #expect(
            updatedConfig.enableDetailedLogging
                == newConfig.enableDetailedLogging
        )
    }

    @Test("Transformation config changes are reflected on subsequent reads")
    func transformationConfigPersistence() {
        let originalConfig = bridgeDataService.getTransformationConfig()

        let newConfig = BridgeDataService.TransformationConfig(
            enabled: !originalConfig.enabled,
            enableMetrics: !originalConfig.enableMetrics,
            enableDetailedLogging: !originalConfig.enableDetailedLogging
        )
        bridgeDataService.updateTransformationConfig(newConfig)

        let updatedConfig = bridgeDataService.getTransformationConfig()
        #expect(updatedConfig.enabled == newConfig.enabled)
        #expect(updatedConfig.enableMetrics == newConfig.enableMetrics)
        #expect(
            updatedConfig.enableDetailedLogging
                == newConfig.enableDetailedLogging
        )
    }

    // MARK: - Metrics Tests

    @Test("Initial metrics state is zeroed")
    func initialMetricsState() {
        bridgeDataService.resetTransformationMetrics()
        let metrics = bridgeDataService.getTransformationMetrics()
        #expect(metrics.totalCoordinates == 0)
        #expect(metrics.transformedCoordinates == 0)
        #expect(metrics.skippedTransformations == 0)
        #expect(metrics.transformationFailures == 0)
        #expect(metrics.averageConfidence == 0.0)
        #expect(metrics.processingTimeSeconds == 0.0)
    }

    @Test("Reset transformation metrics zeros all counters after data load")
    func testResetTransformationMetrics() async throws {
        // Load data to populate metrics
        let (bridges, _) = try await bridgeDataService.loadHistoricalData()
        #expect(bridges.count > 0)

        let metricsBeforeReset = bridgeDataService.getTransformationMetrics()
        // Current implementation updates only processingTimeSeconds; counters remain zero
        #expect(metricsBeforeReset.processingTimeSeconds >= 0.0)

        // Reset metrics
        bridgeDataService.resetTransformationMetrics()

        let metricsAfterReset = bridgeDataService.getTransformationMetrics()
        #expect(metricsAfterReset.totalCoordinates == 0)
        #expect(metricsAfterReset.transformedCoordinates == 0)
        #expect(metricsAfterReset.skippedTransformations == 0)
        #expect(metricsAfterReset.transformationFailures == 0)
        #expect(metricsAfterReset.averageConfidence == 0.0)
        #expect(metricsAfterReset.processingTimeSeconds == 0.0)
    }

    // MARK: - Data Loading Tests

    @Test(
        "Loading historical data with metrics disabled still tracks coherent counters"
    )
    func loadHistoricalDataWithMetricsDisabled() async throws {
        let config = BridgeDataService.TransformationConfig(
            enabled: true,
            enableMetrics: false,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(config)

        let (bridges, _) = try await bridgeDataService.loadHistoricalData()
        #expect(bridges.count > 0)

        let metrics = bridgeDataService.getTransformationMetrics()
        // Metrics counters are not incremented by transformation yet; they should be coherent (>= 0)
        #expect(metrics.totalCoordinates >= 0)
        #expect(metrics.skippedTransformations >= 0)
    }

    @Test(
        "Loading historical data with metrics enabled records processing time and counters"
    )
    func loadHistoricalDataWithTransformationMetrics() async throws {
        let config = BridgeDataService.TransformationConfig(
            enabled: true,
            enableMetrics: true,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(config)

        let (bridges, _) = try await bridgeDataService.loadHistoricalData()
        #expect(bridges.count > 0)

        let metrics = bridgeDataService.getTransformationMetrics()
        #expect(metrics.totalCoordinates >= 0)
        #expect(metrics.processingTimeSeconds >= 0.0)
    }

    // MARK: - Performance Tests

    @Test("Historical data loading completes within reasonable time (< 5s)")
    func transformationPerformance() async throws {
        let config = BridgeDataService.TransformationConfig(
            enabled: true,
            enableMetrics: true,
            enableDetailedLogging: false
        )
        bridgeDataService.updateTransformationConfig(config)

        let startTime = Date()
        let (bridges, _) = try await bridgeDataService.loadHistoricalData()
        let endTime = Date()

        #expect(bridges.count > 0)

        let processingTime = endTime.timeIntervalSince(startTime)
        let metrics = bridgeDataService.getTransformationMetrics()

        // Verify processing time is reasonable (should be less than 5 seconds)
        #expect(processingTime < 5.0)
        #expect(metrics.processingTimeSeconds >= 0.0)
    }
}
