//
//  ETAEstimatorPhase3Tests.swift
//  BridgetTests
//
//  Tests for Phase 3 ETASummary functionality in ETAEstimator
//

import Foundation
import Testing

@testable import Bridget

@Suite("ETAEstimator Phase 3 Tests")
struct ETAEstimatorPhase3Tests {
    private var estimator: ETAEstimator
    private var config: MultiPathConfig

    init() {
        self.config = .testing
        self.estimator = ETAEstimator(config: config)
    }

    // MARK: - ETAEstimate Tests

    @Test("ETAEstimate creation and backward compatibility fields")
    func etaEstimateCreation() throws {
        let summary = ETASummary(
            mean: 300.0,  // 5 minutes
            variance: 25.0,
            min: 270.0,
            max: 330.0
        )

        let arrivalTime = Date()
        let estimate = ETAEstimate(
            nodeID: "test_node",
            summary: summary,
            arrivalTime: arrivalTime
        )

        #expect(estimate.nodeID == "test_node")
        #expect(estimate.summary.mean == 300.0)
        #expect(estimate.summary.variance == 25.0)
        #expect(estimate.arrivalTime == arrivalTime)
        #expect(estimate.travelTimeFromStart == 300.0)  // Backward compatibility
    }

    @Test("ETAEstimate formattedETA contains minutes and ±")
    func etaEstimateFormattedETA() throws {
        let summary = ETASummary(
            mean: 300.0,  // 5 minutes
            variance: 25.0,
            min: 270.0,
            max: 330.0
        )

        let estimate = ETAEstimate(
            nodeID: "test_node",
            summary: summary,
            arrivalTime: Date()
        )

        let formatted = estimate.formattedETA
        #expect(formatted.contains("5 min"))
        #expect(formatted.contains("±"))
    }

    // MARK: - ETAEstimator Phase 3 Methods Tests

    @Test("estimateETAsWithUncertainty returns per-node summaries")
    func estimateETAsWithUncertainty() throws {
        let graph = PathEnumerationService.createPhase1TestFixture().0
        let path = try #require(
            try? PathEnumerationService(config: config).enumeratePaths(
                from: "A",
                to: "C",
                in: graph
            ).first
        )

        let departureTime = Date()
        let estimates = estimator.estimateETAsWithUncertainty(
            for: path,
            departureTime: departureTime
        )

        #expect(estimates.count == 3)  // A, B, C

        // Check departure node (A)
        let departureEstimate = estimates[0]
        #expect(departureEstimate.nodeID == "A")
        #expect(departureEstimate.summary.mean == 0.0)
        #expect(departureEstimate.summary.variance == 0.0)

        // Check intermediate node (B)
        let intermediateEstimate = estimates[1]
        #expect(intermediateEstimate.nodeID == "B")
        #expect(intermediateEstimate.summary.mean > 0.0)
        #expect(intermediateEstimate.summary.variance > 0.0)

        // Check destination node (C)
        let destinationEstimate = estimates[2]
        #expect(destinationEstimate.nodeID == "C")
        #expect(
            destinationEstimate.summary.mean > intermediateEstimate.summary.mean
        )
    }

    @Test("estimateBridgeETAsWithUncertainty returns bridge-only summaries")
    func estimateBridgeETAsWithUncertainty() throws {
        let graph = PathEnumerationService.createPhase1ComplexFixture().0
        let path = try #require(
            try? PathEnumerationService(config: config).enumeratePaths(
                from: "A",
                to: "D",
                in: graph
            ).first
        )

        let departureTime = Date()
        let bridgeEstimates = estimator.estimateBridgeETAsWithUncertainty(
            for: path,
            departureTime: departureTime
        )

        // Should have bridge estimates for bridge crossings
        #expect(bridgeEstimates.count > 0)

        for estimate in bridgeEstimates {
            #expect(estimate.summary.mean > 0.0)
            #expect(estimate.summary.variance > 0.0)
        }
    }

    // TODO: Original complex path statistics test intentionally disabled.

    @Test(
        "PathTravelStatisticsWithUncertainty formatted output and compatibility"
    )
    func pathTravelStatisticsWithUncertaintyFormattedOutput() throws {
        let summary = ETASummary(
            mean: 300.0,  // 5 minutes
            variance: 25.0,
            min: 270.0,
            max: 330.0
        )

        let speedSummary = ETASummary(
            mean: 13.89,  // 50 km/h in m/s
            variance: 1.0,
            min: 11.11,  // 40 km/h
            max: 16.67
        )  // 60 km/h

        let stats = PathTravelStatisticsWithUncertainty(
            totalTravelTime: summary,
            totalDistance: 1000.0,
            averageSpeed: speedSummary,
            bridgeCount: 2,
            estimatedArrivalTime: Date(),
            bridgeArrivalTimes: [Date(), Date()],
            bridgeEstimates: []
        )

        // Test formatted travel time
        let formattedTime = stats.formattedTravelTime
        #expect(formattedTime.contains("5 min"))

        // Test formatted speed
        let formattedSpeed = stats.formattedSpeed
        #expect(formattedSpeed.contains("50.0 km/h"))

        // Test backward compatibility
        #expect(stats.meanTotalTravelTime == 300.0)
        #expect(abs(stats.meanAverageSpeed - 13.89) <= 0.01)
    }

    @Test("Time-of-day uncertainty adjustment: morning vs late-night variance")
    func timeOfDayUncertaintyAdjustment() throws {
        let graph = PathEnumerationService.createPhase1TestFixture().0
        let path = try #require(
            try? PathEnumerationService(config: config).enumeratePaths(
                from: "A",
                to: "C",
                in: graph
            ).first
        )

        // Morning rush hour
        let morningRush = Calendar.current.date(
            bySettingHour: 8,
            minute: 0,
            second: 0,
            of: Date()
        )!
        let morningEstimates = estimator.estimateETAsWithUncertainty(
            for: path,
            departureTime: morningRush
        )

        // Late night
        let lateNight = Calendar.current.date(
            bySettingHour: 23,
            minute: 0,
            second: 0,
            of: Date()
        )!
        let lateNightEstimates = estimator.estimateETAsWithUncertainty(
            for: path,
            departureTime: lateNight
        )

        // Morning rush should have higher variance than late night
        let morningVariance = morningEstimates.last?.summary.variance ?? 0.0
        let lateNightVariance = lateNightEstimates.last?.summary.variance ?? 0.0

        #expect(morningVariance > lateNightVariance)
    }
}
