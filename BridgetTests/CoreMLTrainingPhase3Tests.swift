//
//  CoreMLTrainingPhase3Tests.swift
//  BridgetTests
//
//  Tests for Phase 3 statistical variance functionality in CoreMLTraining
//

import XCTest

@testable import Bridget

final class CoreMLTrainingPhase3Tests: XCTestCase {
  var coreMLTraining: CoreMLTraining!

  override func setUp() {
    super.setUp()
    coreMLTraining = CoreMLTraining(config: CoreMLTrainingConfig.validation)
  }

  override func tearDown() {
    coreMLTraining = nil
    super.tearDown()
  }

  // MARK: - Variance Computation Tests

  func testComputeTrainingLossVariance() {
    // Test with stable loss trend
    let stableLosses = [0.1, 0.095, 0.092, 0.089, 0.087, 0.085, 0.083, 0.081, 0.079, 0.077]
    let variance = coreMLTraining.computeTrainingLossVariance(lossTrend: stableLosses)

    XCTAssertNotNil(variance)
    if let variance = variance {
      XCTAssertEqual(variance.mean, 0.078, accuracy: 0.001)
      XCTAssertGreaterThan(variance.variance, 0)
      XCTAssertLessThan(variance.variance, 0.01)  // Should be small for stable trend
    }
  }

  func testComputeTrainingLossVarianceWithUnstableTrend() {
    // Test with unstable loss trend
    let unstableLosses = [0.1, 0.2, 0.05, 0.15, 0.08, 0.25, 0.03, 0.18, 0.06, 0.22]
    let variance = coreMLTraining.computeTrainingLossVariance(lossTrend: unstableLosses)

    XCTAssertNotNil(variance)
    if let variance = variance {
      // For unstable trend, variance should be significant
      // Using last 20% (2 values): [0.06, 0.22]
      // Expected mean: 0.14, variance should be around 0.0128
      XCTAssertGreaterThan(variance.variance, 0.005)  // Relaxed threshold for unstable trend
    }
  }

  func testComputeTrainingLossVarianceWithEmptyArray() {
    let variance = coreMLTraining.computeTrainingLossVariance(lossTrend: [])
    XCTAssertNil(variance)
  }

  func testComputeValidationAccuracyVariance() {
    // Test with stable accuracy trend
    let stableAccuracies = [0.85, 0.86, 0.87, 0.88, 0.89, 0.90, 0.91, 0.92, 0.93, 0.94]
    let variance = coreMLTraining.computeValidationAccuracyVariance(accuracyTrend: stableAccuracies)

    XCTAssertNotNil(variance)
    if let variance = variance {
      XCTAssertEqual(variance.mean, 0.935, accuracy: 0.001)
      XCTAssertGreaterThan(variance.variance, 0)
      XCTAssertLessThan(variance.variance, 0.01)  // Should be small for stable trend
    }
  }

  func testComputeValidationAccuracyVarianceWithUnstableTrend() {
    // Test with unstable accuracy trend
    let unstableAccuracies = [0.85, 0.75, 0.95, 0.80, 0.90, 0.70, 0.98, 0.82, 0.88, 0.72]
    let variance = coreMLTraining.computeValidationAccuracyVariance(
      accuracyTrend: unstableAccuracies)

    XCTAssertNotNil(variance)
    if let variance = variance {
      // For unstable trend, variance should be significant
      // Using last 20% (2 values): [0.88, 0.72]
      // Expected mean: 0.80, variance should be around 0.0128
      XCTAssertGreaterThan(variance.variance, 0.005)  // Relaxed threshold for unstable trend
    }
  }

  func testComputeValidationAccuracyVarianceWithEmptyArray() {
    let variance = coreMLTraining.computeValidationAccuracyVariance(accuracyTrend: [])
    XCTAssertNil(variance)
  }

  // MARK: - Statistical Metrics Integration Tests

  func testStatisticalMetricsDataStructure() {
    // Test that StatisticalTrainingMetrics can be created and accessed
    let trainingLossStats = ETASummary(mean: 0.1, variance: 0.01, min: 0.05, max: 0.15)
    let predictionAccuracyStats = ETASummary(mean: 0.85, variance: 0.001, min: 0.82, max: 0.88)
    let validationLossStats = ETASummary(mean: 0.12, variance: 0.015, min: 0.06, max: 0.18)
    let etaPredictionVariance = ETASummary(mean: 120.0, variance: 25.0, min: 90.0, max: 150.0)

    let confidenceIntervals = PerformanceConfidenceIntervals(
      accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
      f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
      meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16))

    let errorDistribution = ErrorDistributionMetrics(
      absoluteErrorStats: ETASummary(mean: 0.05, variance: 0.002, min: 0.02, max: 0.08),
      relativeErrorStats: ETASummary(mean: 0.12, variance: 0.005, min: 0.08, max: 0.16),
      withinOneStdDev: 68.2,
      withinTwoStdDev: 95.4)

    let metrics = StatisticalTrainingMetrics(
      trainingLossStats: trainingLossStats,
      validationLossStats: validationLossStats,
      predictionAccuracyStats: predictionAccuracyStats,
      etaPredictionVariance: etaPredictionVariance,
      performanceConfidenceIntervals: confidenceIntervals,
      errorDistribution: errorDistribution)

    // Verify all properties are accessible
    XCTAssertEqual(metrics.trainingLossStats.mean, 0.1, accuracy: 0.001)
    XCTAssertEqual(metrics.predictionAccuracyStats.mean, 0.85, accuracy: 0.001)
    XCTAssertEqual(metrics.etaPredictionVariance.mean, 120.0, accuracy: 0.1)
    XCTAssertEqual(metrics.performanceConfidenceIntervals.accuracy95CI.lower, 0.82, accuracy: 0.001)
    XCTAssertEqual(metrics.errorDistribution.withinOneStdDev, 68.2, accuracy: 0.1)
  }

  // MARK: - UI Integration Tests

  func testPipelineMetricsDataWithStatisticalMetrics() {
    // Test that PipelineMetricsData can include statistical metrics
    let statisticalMetrics = StatisticalTrainingMetrics(
      trainingLossStats: ETASummary(mean: 0.1, variance: 0.01, min: 0.05, max: 0.15),
      validationLossStats: ETASummary(mean: 0.12, variance: 0.015, min: 0.06, max: 0.18),
      predictionAccuracyStats: ETASummary(mean: 0.85, variance: 0.001, min: 0.82, max: 0.88),
      etaPredictionVariance: ETASummary(mean: 120.0, variance: 25.0, min: 90.0, max: 150.0),
      performanceConfidenceIntervals: PerformanceConfidenceIntervals(
        accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
        f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
        meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)),
      errorDistribution: ErrorDistributionMetrics(
        absoluteErrorStats: ETASummary(mean: 0.05, variance: 0.002, min: 0.02, max: 0.08),
        relativeErrorStats: ETASummary(mean: 0.12, variance: 0.005, min: 0.08, max: 0.16),
        withinOneStdDev: 68.2,
        withinTwoStdDev: 95.4))

    let pipelineData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: [
        "DataProcessing": 1.2,
        "FeatureEngineering": 2.1,
        "ModelTraining": 5.3,
      ],
      memoryUsage: [
        "DataProcessing": 256,
        "FeatureEngineering": 384,
        "ModelTraining": 512,
      ],
      validationRates: [
        "DataQualityValidator": 0.95,
        "SchemaValidator": 0.98,
      ],
      errorCounts: [
        "DataProcessing": 0,
        "FeatureEngineering": 1,
        "ModelTraining": 0,
      ],
      recordCounts: [
        "DataProcessing": 1000,
        "FeatureEngineering": 950,
        "ModelTraining": 900,
      ],
      customValidationResults: [
        "DataQualityValidator": true,
        "SchemaValidator": true,
      ],
      statisticalMetrics: statisticalMetrics)

    XCTAssertNotNil(pipelineData.statisticalMetrics)
    if let stats = pipelineData.statisticalMetrics {
      XCTAssertEqual(stats.trainingLossStats.mean, 0.1, accuracy: 0.001)
      XCTAssertEqual(stats.predictionAccuracyStats.mean, 0.85, accuracy: 0.001)
    }
  }

  // MARK: - Edge Cases and Error Handling

  func testVarianceComputationWithSingleValue() {
    let singleLoss = [0.1]
    let variance = coreMLTraining.computeTrainingLossVariance(lossTrend: singleLoss)

    XCTAssertNotNil(variance)
    if let variance = variance {
      XCTAssertEqual(variance.mean, 0.1, accuracy: 0.001)
      XCTAssertEqual(variance.variance, 0.0, accuracy: 0.001)  // Variance should be 0 for single value
    }
  }

  func testVarianceComputationWithTwoValues() {
    let twoLosses = [0.1, 0.2]
    let variance = coreMLTraining.computeTrainingLossVariance(lossTrend: twoLosses)

    XCTAssertNotNil(variance)
    if let variance = variance {
      // For 2 values, last 20% = 1 value (0.2), so mean = 0.2, variance = 0
      XCTAssertEqual(variance.mean, 0.2, accuracy: 0.001)
      XCTAssertEqual(variance.variance, 0.0, accuracy: 0.001)
    }
  }

  func testStableEpochsCalculation() {
    // Test that stable epochs calculation works correctly
    let manyLosses = Array(0..<100).map { Double($0) * 0.001 }  // 100 values
    let variance = coreMLTraining.computeTrainingLossVariance(lossTrend: manyLosses)

    XCTAssertNotNil(variance)
    if let variance = variance {
      // Should use last 20% (20 values) for stable epoch calculation
      let expectedMean = (80..<100).map { Double($0) * 0.001 }.reduce(0, +) / 20
      XCTAssertEqual(variance.mean, expectedMean, accuracy: 0.001)
    }
  }
}
