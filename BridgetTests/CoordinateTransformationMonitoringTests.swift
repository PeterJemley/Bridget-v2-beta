//
//  CoordinateTransformationMonitoringTests.swift
//  BridgetTests
//
//  Purpose: Unit tests for CoordinateTransformationMonitoringService
//  Dependencies: Foundation, Testing
//  Test Coverage:
//    - Event recording and retrieval
//    - Metrics calculation
//    - Alert generation
//    - Bridge-specific metrics
//    - Data export functionality
//

import Foundation
import Testing

@testable import Bridget

@Suite("Coordinate Transformation Monitoring Tests")
@MainActor
struct CoordinateTransformationMonitoringTests {
    private var monitoringService:
        DefaultCoordinateTransformationMonitoringService!

    init() throws {
        monitoringService = DefaultCoordinateTransformationMonitoringService()
    }

    @Test("Monitoring service should record successful transformation events")
    func testRecordSuccessfulTransformation() throws {
        let bridgeId = "test-bridge-1"
        // Ensure endDate is slightly in the future so freshly recorded events are included.
        let timeRange = TimeRange(
            startDate: Date().addingTimeInterval(-60 * 60),
            endDate: Date().addingTimeInterval(60)
        )

        monitoringService.recordSuccessfulTransformation(
            bridgeId: bridgeId,
            sourceSystem: "SeattleAPI",
            targetSystem: "SeattleReference",
            confidence: 0.95,
            processingTimeMs: 5.2,
            distanceImprovementMeters: 150.0,
            userId: "user-1"
        )

        let metrics = monitoringService.getMetrics(timeRange: timeRange)
        #expect(metrics != nil)
        #expect(metrics?.totalEvents == 1)
        #expect(metrics?.successfulEvents == 1)
        #expect(metrics?.successRate == 1.0)
        #expect(metrics?.averageProcessingTimeMs == 5.2)
        #expect(metrics?.averageConfidence == 0.95)
        #expect(metrics?.averageDistanceImprovementMeters == 150.0)
    }

    @Test("Monitoring service should record failed transformation events")
    func testRecordFailedTransformation() throws {
        let bridgeId = "test-bridge-2"
        let timeRange = TimeRange(
            startDate: Date().addingTimeInterval(-60 * 60),
            endDate: Date().addingTimeInterval(60)
        )

        monitoringService.recordFailedTransformation(
            bridgeId: bridgeId,
            sourceSystem: "SeattleAPI",
            targetSystem: "SeattleReference",
            errorMessage: "Transformation matrix not found",
            processingTimeMs: 2.1,
            userId: "user-2"
        )

        let metrics = monitoringService.getMetrics(timeRange: timeRange)
        #expect(metrics != nil)
        #expect(metrics?.totalEvents == 1)
        #expect(metrics?.successfulEvents == 0)
        #expect(metrics?.successRate == 0.0)
        #expect(metrics?.averageProcessingTimeMs == 2.1)
        #expect(metrics?.averageConfidence == nil)
        #expect(metrics?.averageDistanceImprovementMeters == nil)
    }

    @Test("Monitoring service should calculate bridge-specific metrics")
    func bridgeSpecificMetrics() throws {
        let bridgeId = "test-bridge-3"
        let timeRange = TimeRange(
            startDate: Date().addingTimeInterval(-60 * 60),
            endDate: Date().addingTimeInterval(60)
        )

        // Record multiple events for the same bridge
        monitoringService.recordSuccessfulTransformation(
            bridgeId: bridgeId,
            sourceSystem: "SeattleAPI",
            targetSystem: "SeattleReference",
            confidence: 0.9,
            processingTimeMs: 4.0,
            distanceImprovementMeters: 100.0,
            userId: "user-3"
        )

        monitoringService.recordSuccessfulTransformation(
            bridgeId: bridgeId,
            sourceSystem: "SeattleAPI",
            targetSystem: "SeattleReference",
            confidence: 0.8,
            processingTimeMs: 6.0,
            distanceImprovementMeters: 200.0,
            userId: "user-3"
        )

        let bridgeMetrics = monitoringService.getBridgeMetrics(
            bridgeId: bridgeId,
            timeRange: timeRange
        )
        #expect(bridgeMetrics != nil)
        #expect(bridgeMetrics?.bridgeId == bridgeId)
        #expect(bridgeMetrics?.totalEvents == 2)
        #expect(bridgeMetrics?.successfulEvents == 2)
        #expect(bridgeMetrics?.successRate == 1.0)
        #expect(bridgeMetrics?.averageProcessingTimeMs == 5.0)
        // Allow for floating point precision differences
        if let avgConf = bridgeMetrics?.averageConfidence {
            #expect(abs(avgConf - 0.85) < 1e-9)
        } else {
            #expect(Bool(false), "averageConfidence should not be nil")
        }
        #expect(bridgeMetrics?.averageDistanceImprovementMeters == 150.0)
    }

    @Test("Monitoring service should generate alerts for low success rate")
    func testLowSuccessRateAlert() throws {
        // Configure alert threshold
        let alertConfig = AlertConfig(
            minimumSuccessRate: 0.9,
            maximumProcessingTimeMs: 10.0,
            minimumConfidence: 0.8
        )
        monitoringService.updateAlertConfig(alertConfig)

        // Record events that will trigger low success rate alert
        for i in 0..<10 {
            let bridgeId = "bridge-\(i)"
            if i < 7 {  // 70% success rate
                monitoringService.recordSuccessfulTransformation(
                    bridgeId: bridgeId,
                    sourceSystem: "SeattleAPI",
                    targetSystem: "SeattleReference",
                    confidence: 0.95,
                    processingTimeMs: 5.0,
                    distanceImprovementMeters: 100.0,
                    userId: "user-\(i)"
                )
            } else {
                monitoringService.recordFailedTransformation(
                    bridgeId: bridgeId,
                    sourceSystem: "SeattleAPI",
                    targetSystem: "SeattleReference",
                    errorMessage: "Test failure",
                    processingTimeMs: 2.0,
                    userId: "user-\(i)"
                )
            }
        }

        let alerts = monitoringService.checkAlerts()
        #expect(alerts.count > 0)

        let lowSuccessRateAlert = alerts.first {
            $0.alertType == .lowSuccessRate
        }
        #expect(lowSuccessRateAlert != nil)
        #expect(lowSuccessRateAlert?.message.contains("70.0%") == true)
    }

    @Test("Monitoring service should generate alerts for high processing time")
    func testHighProcessingTimeAlert() throws {
        // Configure alert threshold
        let alertConfig = AlertConfig(
            minimumSuccessRate: 0.5,
            maximumProcessingTimeMs: 5.0,
            minimumConfidence: 0.8
        )
        monitoringService.updateAlertConfig(alertConfig)

        // Record events with high processing time
        for i in 0..<5 {
            monitoringService.recordSuccessfulTransformation(
                bridgeId: "bridge-\(i)",
                sourceSystem: "SeattleAPI",
                targetSystem: "SeattleReference",
                confidence: 0.95,
                processingTimeMs: 8.0,  // Above 5ms threshold
                distanceImprovementMeters: 100.0,
                userId: "user-\(i)"
            )
        }

        let alerts = monitoringService.checkAlerts()
        #expect(alerts.count > 0)

        let highProcessingTimeAlert = alerts.first {
            $0.alertType == .highProcessingTime
        }
        #expect(highProcessingTimeAlert != nil)
        #expect(highProcessingTimeAlert?.message.contains("8.00ms") == true)
    }

    @Test("Monitoring service should generate alerts for low confidence")
    func testLowConfidenceAlert() throws {
        // Configure alert threshold
        let alertConfig = AlertConfig(
            minimumSuccessRate: 0.5,
            maximumProcessingTimeMs: 10.0,
            minimumConfidence: 0.9
        )
        monitoringService.updateAlertConfig(alertConfig)

        // Record events with low confidence
        for i in 0..<5 {
            monitoringService.recordSuccessfulTransformation(
                bridgeId: "bridge-\(i)",
                sourceSystem: "SeattleAPI",
                targetSystem: "SeattleReference",
                confidence: 0.8,  // Below 0.9 threshold
                processingTimeMs: 5.0,
                distanceImprovementMeters: 100.0,
                userId: "user-\(i)"
            )
        }

        let alerts = monitoringService.checkAlerts()
        #expect(alerts.count > 0)

        let lowConfidenceAlert = alerts.first { $0.alertType == .lowConfidence }
        #expect(lowConfidenceAlert != nil)
        #expect(lowConfidenceAlert?.message.contains("0.80") == true)
    }

    @Test("Monitoring service should respect alert cooldown")
    func alertCooldown() throws {
        // Configure short cooldown
        let alertConfig = AlertConfig(
            minimumSuccessRate: 0.9,
            maximumProcessingTimeMs: 10.0,
            minimumConfidence: 0.8,
            alertCooldownSeconds: 1
        )
        monitoringService.updateAlertConfig(alertConfig)

        // Record events that will trigger alert
        monitoringService.recordFailedTransformation(
            bridgeId: "test-bridge",
            sourceSystem: "SeattleAPI",
            targetSystem: "SeattleReference",
            errorMessage: "Test failure",
            processingTimeMs: 2.0,
            userId: "user-1"
        )

        // First check should generate alerts
        let alerts1 = monitoringService.checkAlerts()
        #expect(alerts1.count > 0)

        // Second check immediately after should not generate alerts due to cooldown
        let alerts2 = monitoringService.checkAlerts()
        #expect(alerts2.count == 0)
    }

    @Test("Monitoring service should export monitoring data")
    func testExportMonitoringData() throws {
        let timeRange = TimeRange(
            startDate: Date().addingTimeInterval(-60 * 60),
            endDate: Date().addingTimeInterval(60)
        )

        // Record some events
        monitoringService.recordSuccessfulTransformation(
            bridgeId: "export-test-bridge",
            sourceSystem: "SeattleAPI",
            targetSystem: "SeattleReference",
            confidence: 0.95,
            processingTimeMs: 5.0,
            distanceImprovementMeters: 100.0,
            userId: "export-user"
        )

        let exportData = monitoringService.exportMonitoringData(
            timeRange: timeRange
        )
        #expect(exportData != nil)

        // Verify data can be decoded
        if let data = exportData {
            let json =
                try JSONSerialization.jsonObject(with: data) as? [String: Any]
            #expect(json != nil)
            #expect(json?["version"] as? String == "1.0")
            #expect(json?["exportTimestamp"] != nil)
        }
    }

    @Test("Monitoring service should clear old events")
    func testClearOldEvents() throws {
        let timeRange = TimeRange(
            startDate: Date().addingTimeInterval(-60 * 60),
            endDate: Date().addingTimeInterval(60)
        )

        // Record events
        monitoringService.recordSuccessfulTransformation(
            bridgeId: "old-bridge",
            sourceSystem: "SeattleAPI",
            targetSystem: "SeattleReference",
            confidence: 0.95,
            processingTimeMs: 5.0,
            distanceImprovementMeters: 100.0,
            userId: "old-user"
        )

        // Verify events exist
        let metricsBefore = monitoringService.getMetrics(timeRange: timeRange)
        #expect(metricsBefore?.totalEvents == 1)

        // Clear events before a future cutoff to ensure removal of newly added events
        let cutoffDate = Date().addingTimeInterval(60)  // 1 minute in the future
        monitoringService.clearOldEvents(before: cutoffDate)

        // Verify events are cleared
        let metricsAfter = monitoringService.getMetrics(timeRange: timeRange)
        #expect((metricsAfter?.totalEvents ?? 0) == 0)
    }

    @Test("Monitoring service should get all bridge IDs")
    func testGetAllBridgeIds() throws {
        // Record events for multiple bridges
        let bridgeIds = ["bridge-1", "bridge-2", "bridge-3"]

        for bridgeId in bridgeIds {
            monitoringService.recordSuccessfulTransformation(
                bridgeId: bridgeId,
                sourceSystem: "SeattleAPI",
                targetSystem: "SeattleReference",
                confidence: 0.95,
                processingTimeMs: 5.0,
                distanceImprovementMeters: 100.0,
                userId: "user-\(bridgeId)"
            )
        }

        let allBridgeIds = monitoringService.getAllBridgeIds()
        #expect(allBridgeIds.count == 3)

        for bridgeId in bridgeIds {
            #expect(allBridgeIds.contains(bridgeId))
        }
    }

    @Test("Monitoring service should get recent alerts")
    func testGetRecentAlerts() throws {
        // Configure alert threshold
        let alertConfig = AlertConfig(
            minimumSuccessRate: 0.9,
            maximumProcessingTimeMs: 10.0,
            minimumConfidence: 0.8
        )
        monitoringService.updateAlertConfig(alertConfig)

        // Record events that will trigger alerts
        for i in 0..<5 {
            monitoringService.recordFailedTransformation(
                bridgeId: "alert-bridge-\(i)",
                sourceSystem: "SeattleAPI",
                targetSystem: "SeattleReference",
                errorMessage: "Test failure",
                processingTimeMs: 2.0,
                userId: "alert-user-\(i)"
            )
        }

        // Generate alerts
        _ = monitoringService.checkAlerts()

        // Get recent alerts
        let recentAlerts = monitoringService.getRecentAlerts(limit: 3)
        #expect(recentAlerts.count <= 3)
        #expect(recentAlerts.count > 0)
    }

    @Test("TimeRange convenience properties should work correctly")
    func timeRangeConvenienceProperties() throws {
        // Test static convenience properties
        let lastHour = TimeRange.lastHour
        let last24Hours = TimeRange.last24Hours
        let last7Days = TimeRange.last7Days
        let last30Days = TimeRange.last30Days

        // Allow small floating point differences when checking durations
        #expect(abs(lastHour.duration - Double(60 * 60)) < 0.01)
        #expect(abs(last24Hours.duration - Double(24 * 60 * 60)) < 0.01)
        #expect(abs(last7Days.duration - Double(7 * 24 * 60 * 60)) < 0.01)
        #expect(abs(last30Days.duration - Double(30 * 24 * 60 * 60)) < 0.01)

        // Test contains method using dates derived from the static ranges (avoid current now boundary)
        let hourMid = lastHour.startDate.addingTimeInterval(
            lastHour.duration / 2
        )
        let dayMid = last24Hours.startDate.addingTimeInterval(
            last24Hours.duration / 2
        )
        #expect(lastHour.contains(hourMid))
        #expect(last24Hours.contains(dayMid))
    }

    @Test("AlertConfig should have correct default values")
    func alertConfigDefaults() throws {
        let defaultConfig = AlertConfig()

        #expect(defaultConfig.minimumSuccessRate == 0.9)
        #expect(defaultConfig.maximumProcessingTimeMs == 10.0)
        #expect(defaultConfig.minimumConfidence == 0.8)
        #expect(defaultConfig.alertCooldownSeconds == 300)
    }

    @Test("AlertType should have correct descriptions")
    func alertTypeDescriptions() throws {
        #expect(AlertType.lowSuccessRate.description == "Low Success Rate")
        #expect(
            AlertType.highProcessingTime.description == "High Processing Time"
        )
        #expect(AlertType.lowConfidence.description == "Low Confidence")
        #expect(AlertType.failureSpike.description == "Failure Spike")
        #expect(
            AlertType.accuracyDegradation.description == "Accuracy Degradation"
        )
    }
}
