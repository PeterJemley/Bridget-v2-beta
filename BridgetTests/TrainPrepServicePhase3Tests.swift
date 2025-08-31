//
//  TrainPrepServicePhase3Tests.swift
//  BridgetTests
//
//  Tests for Phase 3 statistical metrics functionality in TrainPrepService
//

import XCTest

@testable import Bridget

final class TrainPrepServicePhase3Tests: XCTestCase {
  private var service: TrainPrepService!

  override func setUp() {
    super.setUp()
    service = TrainPrepService()
  }

  override func tearDown() {
    service = nil
    super.tearDown()
  }

  // MARK: - StatisticalTrainingMetrics Tests

  func testStatisticalTrainingMetricsCreation() {
    let trainingLossStats = ETASummary(mean: 0.1,
                                       variance: 0.01,
                                       min: 0.05,
                                       max: 0.15)
    let validationLossStats = ETASummary(mean: 0.12,
                                         variance: 0.015,
                                         min: 0.06,
                                         max: 0.18)
    let predictionAccuracyStats = ETASummary(mean: 0.85,
                                             variance: 0.001,
                                             min: 0.82,
                                             max: 0.88)
    let etaPredictionVariance = ETASummary(mean: 300.0,
                                           variance: 900.0,
                                           min: 240.0,
                                           max: 360.0)

    let confidenceIntervals = PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
                                                             f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.86),
                                                             meanError95CI: ConfidenceInterval(lower: 0.0, upper: 0.1))

    let errorDistribution = ErrorDistributionMetrics(absoluteErrorStats: ETASummary(mean: 0.05,
                                                                                    variance: 0.001,
                                                                                    min: 0.0,
                                                                                    max: 0.15),
                                                     relativeErrorStats: ETASummary(mean: 5.0,
                                                                                    variance: 1.0,
                                                                                    min: 0.0,
                                                                                    max: 15.0),
                                                     withinOneStdDev: 68.0,
                                                     withinTwoStdDev: 95.0)

    let metrics = StatisticalTrainingMetrics(trainingLossStats: trainingLossStats,
                                             validationLossStats: validationLossStats,
                                             predictionAccuracyStats: predictionAccuracyStats,
                                             etaPredictionVariance: etaPredictionVariance,
                                             performanceConfidenceIntervals: confidenceIntervals,
                                             errorDistribution: errorDistribution)

    XCTAssertEqual(metrics.trainingLossStats.mean, 0.1)
    XCTAssertEqual(metrics.validationLossStats.mean, 0.12)
    XCTAssertEqual(metrics.predictionAccuracyStats.mean, 0.85)
    XCTAssertEqual(metrics.etaPredictionVariance.mean, 300.0)
    XCTAssertEqual(metrics.performanceConfidenceIntervals.accuracy95CI.lower,
                   0.82)
    XCTAssertEqual(metrics.performanceConfidenceIntervals.accuracy95CI.upper,
                   0.88)
    XCTAssertEqual(metrics.errorDistribution.withinOneStdDev, 68.0)
    XCTAssertEqual(metrics.errorDistribution.withinTwoStdDev, 95.0)
  }

  // MARK: - PerformanceConfidenceIntervals Tests

  func testPerformanceConfidenceIntervalsCreation() {
    let intervals = PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
                                                   f1Score95CI: ConfidenceInterval(lower: 0.75, upper: 0.85),
                                                   meanError95CI: ConfidenceInterval(lower: 0.0, upper: 0.05))

    XCTAssertEqual(intervals.accuracy95CI.lower, 0.80)
    XCTAssertEqual(intervals.accuracy95CI.upper, 0.90)
    XCTAssertEqual(intervals.f1Score95CI.lower, 0.75)
    XCTAssertEqual(intervals.f1Score95CI.upper, 0.85)
    XCTAssertEqual(intervals.meanError95CI.lower, 0.0)
    XCTAssertEqual(intervals.meanError95CI.upper, 0.05)
  }

  // MARK: - ErrorDistributionMetrics Tests

  func testErrorDistributionMetricsCreation() {
    let absoluteErrorStats = ETASummary(mean: 0.03,
                                        variance: 0.0009,
                                        min: 0.0,
                                        max: 0.08)
    let relativeErrorStats = ETASummary(mean: 3.0,
                                        variance: 0.5,
                                        min: 0.0,
                                        max: 8.0)

    let errorDistribution = ErrorDistributionMetrics(absoluteErrorStats: absoluteErrorStats,
                                                     relativeErrorStats: relativeErrorStats,
                                                     withinOneStdDev: 70.0,
                                                     withinTwoStdDev: 96.0)

    XCTAssertEqual(errorDistribution.absoluteErrorStats.mean, 0.03)
    XCTAssertEqual(errorDistribution.relativeErrorStats.mean, 3.0)
    XCTAssertEqual(errorDistribution.withinOneStdDev, 70.0)
    XCTAssertEqual(errorDistribution.withinTwoStdDev, 96.0)
  }

  // MARK: - ConfidenceInterval Tests

  func testConfidenceIntervalCreation() {
    let interval = ConfidenceInterval(lower: 0.75, upper: 0.85)

    XCTAssertEqual(interval.lower, 0.75)
    XCTAssertEqual(interval.upper, 0.85)
  }

  func testConfidenceIntervalEquality() {
    let interval1 = ConfidenceInterval(lower: 0.75, upper: 0.85)
    let interval2 = ConfidenceInterval(lower: 0.75, upper: 0.85)
    let interval3 = ConfidenceInterval(lower: 0.80, upper: 0.85)

    XCTAssertEqual(interval1, interval2)
    XCTAssertNotEqual(interval1, interval3)
  }

  // MARK: - Codable Tests

  func testStatisticalTrainingMetricsCodable() {
    let trainingLossStats = ETASummary(mean: 0.1,
                                       variance: 0.01,
                                       min: 0.05,
                                       max: 0.15)
    let validationLossStats = ETASummary(mean: 0.12,
                                         variance: 0.015,
                                         min: 0.06,
                                         max: 0.18)
    let predictionAccuracyStats = ETASummary(mean: 0.85,
                                             variance: 0.001,
                                             min: 0.82,
                                             max: 0.88)
    let etaPredictionVariance = ETASummary(mean: 300.0,
                                           variance: 900.0,
                                           min: 240.0,
                                           max: 360.0)

    let confidenceIntervals = PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
                                                             f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.86),
                                                             meanError95CI: ConfidenceInterval(lower: 0.0, upper: 0.1))

    let errorDistribution = ErrorDistributionMetrics(absoluteErrorStats: ETASummary(mean: 0.05,
                                                                                    variance: 0.001,
                                                                                    min: 0.0,
                                                                                    max: 0.15),
                                                     relativeErrorStats: ETASummary(mean: 5.0,
                                                                                    variance: 1.0,
                                                                                    min: 0.0,
                                                                                    max: 15.0),
                                                     withinOneStdDev: 68.0,
                                                     withinTwoStdDev: 95.0)

    let originalMetrics = StatisticalTrainingMetrics(trainingLossStats: trainingLossStats,
                                                     validationLossStats: validationLossStats,
                                                     predictionAccuracyStats: predictionAccuracyStats,
                                                     etaPredictionVariance: etaPredictionVariance,
                                                     performanceConfidenceIntervals: confidenceIntervals,
                                                     errorDistribution: errorDistribution)

    // Test encoding
    let encoder = JSONEncoder()
    let data = try! encoder.encode(originalMetrics)

    // Test decoding
    let decoder = JSONDecoder()
    let decodedMetrics = try! decoder.decode(StatisticalTrainingMetrics.self,
                                             from: data)

    // Verify round-trip
    XCTAssertEqual(originalMetrics.trainingLossStats.mean,
                   decodedMetrics.trainingLossStats.mean)
    XCTAssertEqual(originalMetrics.validationLossStats.mean,
                   decodedMetrics.validationLossStats.mean)
    XCTAssertEqual(originalMetrics.predictionAccuracyStats.mean,
                   decodedMetrics.predictionAccuracyStats.mean)
    XCTAssertEqual(originalMetrics.etaPredictionVariance.mean,
                   decodedMetrics.etaPredictionVariance.mean)
    XCTAssertEqual(originalMetrics.performanceConfidenceIntervals.accuracy95CI.lower,
                   decodedMetrics.performanceConfidenceIntervals.accuracy95CI.lower)
    XCTAssertEqual(originalMetrics.performanceConfidenceIntervals.accuracy95CI.upper,
                   decodedMetrics.performanceConfidenceIntervals.accuracy95CI.upper)
    XCTAssertEqual(originalMetrics.errorDistribution.withinOneStdDev,
                   decodedMetrics.errorDistribution.withinOneStdDev)
    XCTAssertEqual(originalMetrics.errorDistribution.withinTwoStdDev,
                   decodedMetrics.errorDistribution.withinTwoStdDev)
  }

  func testConfidenceIntervalCodable() {
    let originalInterval = ConfidenceInterval(lower: 0.75, upper: 0.85)

    // Test encoding
    let encoder = JSONEncoder()
    let data = try! encoder.encode(originalInterval)

    // Test decoding
    let decoder = JSONDecoder()
    let decodedInterval = try! decoder.decode(ConfidenceInterval.self,
                                              from: data)

    // Verify round-trip
    XCTAssertEqual(originalInterval.lower, decodedInterval.lower)
    XCTAssertEqual(originalInterval.upper, decodedInterval.upper)
  }
}
