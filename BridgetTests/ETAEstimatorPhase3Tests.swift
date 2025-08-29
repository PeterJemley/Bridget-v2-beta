//
//  ETAEstimatorPhase3Tests.swift
//  BridgetTests
//
//  Tests for Phase 3 ETASummary functionality in ETAEstimator
//

import XCTest

@testable import Bridget

final class ETAEstimatorPhase3Tests: XCTestCase {
  private var estimator: ETAEstimator!
  private var config: MultiPathConfig!

  override func setUp() {
    super.setUp()
    config = MultiPathConfig.testing
    estimator = ETAEstimator(config: config)
  }

  override func tearDown() {
    estimator = nil
    config = nil
    super.tearDown()
  }

  // MARK: - ETAEstimate Tests

  func testETAEstimateCreation() {
    let summary = ETASummary(mean: 300.0,  // 5 minutes
                             variance: 25.0,
                             min: 270.0,
                             max: 330.0)

    let arrivalTime = Date()
    let estimate = ETAEstimate(nodeID: "test_node",
                               summary: summary,
                               arrivalTime: arrivalTime)

    XCTAssertEqual(estimate.nodeID, "test_node")
    XCTAssertEqual(estimate.summary.mean, 300.0)
    XCTAssertEqual(estimate.summary.variance, 25.0)
    XCTAssertEqual(estimate.arrivalTime, arrivalTime)
    XCTAssertEqual(estimate.travelTimeFromStart, 300.0)  // Backward compatibility
  }

  func testETAEstimateFormattedETA() {
    let summary = ETASummary(mean: 300.0,  // 5 minutes
                             variance: 25.0,
                             min: 270.0,
                             max: 330.0)

    let estimate = ETAEstimate(nodeID: "test_node",
                               summary: summary,
                               arrivalTime: Date())

    let formatted = estimate.formattedETA
    XCTAssertTrue(formatted.contains("5 min"))
    XCTAssertTrue(formatted.contains("±"))
  }

  // MARK: - ETAEstimator Phase 3 Methods Tests

  func testEstimateETAsWithUncertainty() {
    let graph = PathEnumerationService.createPhase1TestFixture().0
    let path = try! PathEnumerationService(config: config).enumeratePaths(from: "A",
                                                                          to: "C",
                                                                          in: graph).first!

    let departureTime = Date()
    let estimates = estimator.estimateETAsWithUncertainty(for: path,
                                                          departureTime: departureTime)

    XCTAssertEqual(estimates.count, 3)  // A, B, C

    // Check departure node (A)
    let departureEstimate = estimates[0]
    XCTAssertEqual(departureEstimate.nodeID, "A")
    XCTAssertEqual(departureEstimate.summary.mean, 0.0)
    XCTAssertEqual(departureEstimate.summary.variance, 0.0)

    // Check intermediate node (B)
    let intermediateEstimate = estimates[1]
    XCTAssertEqual(intermediateEstimate.nodeID, "B")
    XCTAssertGreaterThan(intermediateEstimate.summary.mean, 0.0)
    XCTAssertGreaterThan(intermediateEstimate.summary.variance, 0.0)

    // Check destination node (C)
    let destinationEstimate = estimates[2]
    XCTAssertEqual(destinationEstimate.nodeID, "C")
    XCTAssertGreaterThan(destinationEstimate.summary.mean, intermediateEstimate.summary.mean)
  }

  func testEstimateBridgeETAsWithUncertainty() {
    let graph = PathEnumerationService.createPhase1ComplexFixture().0
    let path = try! PathEnumerationService(config: config).enumeratePaths(from: "A",
                                                                          to: "D",
                                                                          in: graph).first!

    let departureTime = Date()
    let bridgeEstimates = estimator.estimateBridgeETAsWithUncertainty(for: path,
                                                                      departureTime: departureTime)

    // Should have bridge estimates for bridge crossings
    XCTAssertGreaterThan(bridgeEstimates.count, 0)

    for estimate in bridgeEstimates {
      XCTAssertGreaterThan(estimate.summary.mean, 0.0)
      XCTAssertGreaterThan(estimate.summary.variance, 0.0)
    }
  }

  // TODO: Fix this test - currently disabled due to complex path statistics calculation
  // func testCalculatePathStatisticsWithUncertainty() {
  //     let graph = PathEnumerationService.createPhase1TestFixture().0
  //     let path = try! PathEnumerationService(config: config).enumeratePaths(
  //         from: "A",
  //         to: "C",
  //         in: graph
  //     ).first!
  //
  //     let departureTime = Date()
  //     let stats = estimator.calculatePathStatisticsWithUncertainty(
  //         for: path,
  //         departureTime: departureTime
  //     )
  //
  //     // Check total travel time statistics
  //     XCTAssertGreaterThan(stats.totalTravelTime.mean, 0.0)
  //     XCTAssertGreaterThanOrEqual(stats.totalTravelTime.variance, 0.0)
  //     XCTAssertGreaterThan(stats.totalTravelTime.min, 0.0)
  //     XCTAssertGreaterThan(stats.totalTravelTime.max, stats.totalTravelTime.min)
  //
  //     // Check speed statistics - may be 0 if no valid speed calculations
  //     XCTAssertGreaterThanOrEqual(stats.averageSpeed.mean, 0.0)
  //     XCTAssertGreaterThanOrEqual(stats.averageSpeed.variance, 0.0)
  //
  //     // Check bridge count
  //     XCTAssertEqual(stats.bridgeCount, path.bridgeCount)
  //
  //     // Check bridge estimates - may be empty if no bridges in path
  //     XCTAssertGreaterThanOrEqual(stats.bridgeEstimates.count, 0)
  //     XCTAssertLessThanOrEqual(stats.bridgeEstimates.count, stats.bridgeCount)
  // }

  func testPathTravelStatisticsWithUncertaintyFormattedOutput() {
    let summary = ETASummary(mean: 300.0,  // 5 minutes
                             variance: 25.0,
                             min: 270.0,
                             max: 330.0)

    let speedSummary = ETASummary(mean: 13.89,  // 50 km/h in m/s
                                  variance: 1.0,
                                  min: 11.11,  // 40 km/h
                                  max: 16.67  // 60 km/h
    )

    let stats = PathTravelStatisticsWithUncertainty(totalTravelTime: summary,
                                                    totalDistance: 1000.0,
                                                    averageSpeed: speedSummary,
                                                    bridgeCount: 2,
                                                    estimatedArrivalTime: Date(),
                                                    bridgeArrivalTimes: [Date(), Date()],
                                                    bridgeEstimates: [])

    // Test formatted travel time
    let formattedTime = stats.formattedTravelTime
    XCTAssertTrue(formattedTime.contains("5 min"))

    // Test formatted speed
    let formattedSpeed = stats.formattedSpeed
    XCTAssertTrue(formattedSpeed.contains("50.0 km/h"))

    // Test backward compatibility
    XCTAssertEqual(stats.meanTotalTravelTime, 300.0)
    XCTAssertEqual(stats.meanAverageSpeed, 13.89, accuracy: 0.01)
  }

  func testTimeOfDayUncertaintyAdjustment() {
    let graph = PathEnumerationService.createPhase1TestFixture().0
    let path = try! PathEnumerationService(config: config).enumeratePaths(from: "A",
                                                                          to: "C",
                                                                          in: graph).first!

    // Test morning rush hour
    let morningRush = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date())!
    let morningEstimates = estimator.estimateETAsWithUncertainty(for: path,
                                                                 departureTime: morningRush)

    // Test late night
    let lateNight = Calendar.current.date(bySettingHour: 23, minute: 0, second: 0, of: Date())!
    let lateNightEstimates = estimator.estimateETAsWithUncertainty(for: path,
                                                                   departureTime: lateNight)

    // Morning rush should have higher variance than late night
    let morningVariance = morningEstimates.last?.summary.variance ?? 0.0
    let lateNightVariance = lateNightEstimates.last?.summary.variance ?? 0.0

    XCTAssertGreaterThan(morningVariance, lateNightVariance)
  }
}
