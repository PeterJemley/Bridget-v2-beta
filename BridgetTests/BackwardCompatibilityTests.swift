import XCTest

@testable import Bridget

final class BackwardCompatibilityTests: XCTestCase {

  // MARK: - PipelineMetricsData Backward Compatibility

  func testPipelineMetricsDataBackwardCompatibility() {
    // Test that old-style PipelineMetricsData still works
    let oldData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: ["DataProcessing": 1.0],
      memoryUsage: ["DataProcessing": 100],
      validationRates: ["Validator": 0.95],
      errorCounts: ["DataProcessing": 0],
      recordCounts: ["DataProcessing": 1000],
      customValidationResults: nil,
      statisticalMetrics: nil
    )

    // Verify old fields still work
    XCTAssertNotNil(oldData.timestamp)
    XCTAssertEqual(oldData.stageDurations["DataProcessing"], 1.0)
    XCTAssertEqual(oldData.memoryUsage["DataProcessing"], 100)
    XCTAssertEqual(oldData.validationRates["Validator"], 0.95)
    XCTAssertEqual(oldData.errorCounts["DataProcessing"], 0)
    XCTAssertEqual(oldData.recordCounts["DataProcessing"], 1000)
    XCTAssertNil(oldData.customValidationResults)

    // Verify new field is nil for old data
    XCTAssertNil(oldData.statisticalMetrics)

    // Verify computed properties still work
    XCTAssertEqual(oldData.stageMetrics.count, 1)
    XCTAssertEqual(oldData.stageMetrics.first?.stage, "DataProcessing")
  }

  func testPipelineMetricsDataWithNewFeatures() {
    // Test that new-style PipelineMetricsData works with statistical metrics
    let statisticalMetrics = StatisticalTrainingMetrics(
      trainingLossStats: ETASummary(mean: 0.1, variance: 0.01, min: 0.05, max: 0.15),
      validationLossStats: ETASummary(mean: 0.12, variance: 0.015, min: 0.06, max: 0.18),
      predictionAccuracyStats: ETASummary(mean: 0.85, variance: 0.001, min: 0.82, max: 0.88),
      etaPredictionVariance: ETASummary(mean: 120.0, variance: 25.0, min: 90.0, max: 150.0),
      performanceConfidenceIntervals: PerformanceConfidenceIntervals(
        accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
        f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
        meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)
      ),
      errorDistribution: ErrorDistributionMetrics(
        absoluteErrorStats: ETASummary(mean: 0.05, variance: 0.002, min: 0.02, max: 0.08),
        relativeErrorStats: ETASummary(mean: 0.12, variance: 0.005, min: 0.08, max: 0.16),
        withinOneStdDev: 68.2,
        withinTwoStdDev: 95.4
      )
    )

    let newData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: ["DataProcessing": 1.0],
      memoryUsage: ["DataProcessing": 100],
      validationRates: ["Validator": 0.95],
      errorCounts: ["DataProcessing": 0],
      recordCounts: ["DataProcessing": 1000],
      customValidationResults: nil,
      statisticalMetrics: statisticalMetrics
    )

    // Verify old fields still work
    XCTAssertNotNil(newData.timestamp)
    XCTAssertEqual(newData.stageDurations["DataProcessing"], 1.0)
    XCTAssertEqual(newData.memoryUsage["DataProcessing"], 100)
    XCTAssertEqual(newData.validationRates["Validator"], 0.95)
    XCTAssertEqual(newData.errorCounts["DataProcessing"], 0)
    XCTAssertEqual(newData.recordCounts["DataProcessing"], 1000)
    XCTAssertNil(newData.customValidationResults)

    // Verify new field works
    XCTAssertNotNil(newData.statisticalMetrics)
    XCTAssertEqual(newData.statisticalMetrics?.trainingLossStats.mean ?? 0.0, 0.1, accuracy: 0.001)
    XCTAssertEqual(
      newData.statisticalMetrics?.predictionAccuracyStats.mean ?? 0.0, 0.85, accuracy: 0.001)

    // Verify computed properties still work
    XCTAssertEqual(newData.stageMetrics.count, 1)
    XCTAssertEqual(newData.stageMetrics.first?.stage, "DataProcessing")
  }

  // MARK: - CoreMLTraining Backward Compatibility

  func testCoreMLTrainingBackwardCompatibility() {
    // Test that existing CoreMLTraining functionality still works
    let coreMLTraining = CoreMLTraining(config: CoreMLTrainingConfig.validation)

    // Verify existing methods still work
    XCTAssertNotNil(coreMLTraining)

    // Test that new methods are available but don't break existing functionality
    let emptyLossTrend: [Double] = []
    let emptyAccuracyTrend: [Double] = []

    // These should return nil for empty data (existing behavior)
    XCTAssertNil(coreMLTraining.computeTrainingLossVariance(lossTrend: emptyLossTrend))
    XCTAssertNil(
      coreMLTraining.computeValidationAccuracyVariance(accuracyTrend: emptyAccuracyTrend))
  }

  // MARK: - UI Backward Compatibility

  func testUIBackwardCompatibility() {
    // Test that UI components handle missing statistical metrics gracefully

    // Create data without statistical metrics (old format)
    let oldData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: ["DataProcessing": 1.0],
      memoryUsage: ["DataProcessing": 100],
      validationRates: ["Validator": 0.95],
      errorCounts: ["DataProcessing": 0],
      recordCounts: ["DataProcessing": 1000],
      customValidationResults: nil,
      statisticalMetrics: nil
    )

    // Verify UI can handle old data
    XCTAssertNil(oldData.statisticalMetrics)

    // Test that StatisticalUncertaintySection can be created with nil metrics
    // (This would be tested in UI tests, but we can verify the data structure)
    XCTAssertNil(oldData.statisticalMetrics)
  }

  // MARK: - Serialization Backward Compatibility

  func testSerializationBackwardCompatibility() {
    // Test that old data can still be serialized/deserialized

    let oldData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: ["DataProcessing": 1.0],
      memoryUsage: ["DataProcessing": 100],
      validationRates: ["Validator": 0.95],
      errorCounts: ["DataProcessing": 0],
      recordCounts: ["DataProcessing": 1000],
      customValidationResults: nil,
      statisticalMetrics: nil
    )

    // Test JSON encoding/decoding
    do {
      let encoder = JSONEncoder()
      let data = try encoder.encode(oldData)

      let decoder = JSONDecoder()
      let decodedData = try decoder.decode(PipelineMetricsData.self, from: data)

      // Verify all fields are preserved
      XCTAssertEqual(
        oldData.timestamp.timeIntervalSince1970, decodedData.timestamp.timeIntervalSince1970,
        accuracy: 1.0)
      XCTAssertEqual(oldData.stageDurations, decodedData.stageDurations)
      XCTAssertEqual(oldData.memoryUsage, decodedData.memoryUsage)
      XCTAssertEqual(oldData.validationRates, decodedData.validationRates)
      XCTAssertEqual(oldData.errorCounts, decodedData.errorCounts)
      XCTAssertEqual(oldData.recordCounts, decodedData.recordCounts)
      XCTAssertEqual(oldData.customValidationResults, decodedData.customValidationResults)
      XCTAssertNil(decodedData.statisticalMetrics)

    } catch {
      XCTFail("Serialization failed: \(error)")
    }
  }

  func testSerializationWithNewFeatures() {
    // Test that new data with statistical metrics can be serialized/deserialized

    let statisticalMetrics = StatisticalTrainingMetrics(
      trainingLossStats: ETASummary(mean: 0.1, variance: 0.01, min: 0.05, max: 0.15),
      validationLossStats: ETASummary(mean: 0.12, variance: 0.015, min: 0.06, max: 0.18),
      predictionAccuracyStats: ETASummary(mean: 0.85, variance: 0.001, min: 0.82, max: 0.88),
      etaPredictionVariance: ETASummary(mean: 120.0, variance: 25.0, min: 90.0, max: 150.0),
      performanceConfidenceIntervals: PerformanceConfidenceIntervals(
        accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
        f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
        meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)
      ),
      errorDistribution: ErrorDistributionMetrics(
        absoluteErrorStats: ETASummary(mean: 0.05, variance: 0.002, min: 0.02, max: 0.08),
        relativeErrorStats: ETASummary(mean: 0.12, variance: 0.005, min: 0.08, max: 0.16),
        withinOneStdDev: 68.2,
        withinTwoStdDev: 95.4
      )
    )

    let newData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: ["DataProcessing": 1.0],
      memoryUsage: ["DataProcessing": 100],
      validationRates: ["Validator": 0.95],
      errorCounts: ["DataProcessing": 0],
      recordCounts: ["DataProcessing": 1000],
      customValidationResults: nil,
      statisticalMetrics: statisticalMetrics
    )

    // Test JSON encoding/decoding
    do {
      let encoder = JSONEncoder()
      let data = try encoder.encode(newData)

      let decoder = JSONDecoder()
      let decodedData = try decoder.decode(PipelineMetricsData.self, from: data)

      // Verify all fields are preserved
      XCTAssertEqual(
        newData.timestamp.timeIntervalSince1970, decodedData.timestamp.timeIntervalSince1970,
        accuracy: 1.0)
      XCTAssertEqual(newData.stageDurations, decodedData.stageDurations)
      XCTAssertEqual(newData.memoryUsage, decodedData.memoryUsage)
      XCTAssertEqual(newData.validationRates, decodedData.validationRates)
      XCTAssertEqual(newData.errorCounts, decodedData.errorCounts)
      XCTAssertEqual(newData.recordCounts, decodedData.recordCounts)
      XCTAssertEqual(newData.customValidationResults, decodedData.customValidationResults)

      // Verify statistical metrics are preserved
      XCTAssertNotNil(decodedData.statisticalMetrics)
      XCTAssertEqual(
        newData.statisticalMetrics?.trainingLossStats.mean ?? 0.0,
        decodedData.statisticalMetrics?.trainingLossStats.mean ?? 0.0, accuracy: 0.001)
      XCTAssertEqual(
        newData.statisticalMetrics?.predictionAccuracyStats.mean ?? 0.0,
        decodedData.statisticalMetrics?.predictionAccuracyStats.mean ?? 0.0, accuracy: 0.001)

    } catch {
      XCTFail("Serialization failed: \(error)")
    }
  }

  // MARK: - API Evolution Tests

  func testOptionalFeatureHandling() {
    // Test that applications can safely handle optional statistical metrics

    let oldData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: ["DataProcessing": 1.0],
      memoryUsage: ["DataProcessing": 100],
      validationRates: ["Validator": 0.95],
      errorCounts: ["DataProcessing": 0],
      recordCounts: ["DataProcessing": 1000],
      customValidationResults: nil,
      statisticalMetrics: nil
    )

    // Safe access pattern
    if let stats = oldData.statisticalMetrics {
      // This should not execute for old data
      XCTFail("Statistical metrics should be nil for old data")
    } else {
      // This is the expected behavior for old data
      XCTAssertTrue(true, "Old data correctly has nil statistical metrics")
    }

    // Test that core functionality still works without statistical metrics
    XCTAssertNotNil(oldData.timestamp)
    XCTAssertEqual(oldData.stageMetrics.count, 1)
  }

  func testGracefulDegradation() {
    // Test that applications can gracefully handle missing statistical metrics

    let oldData = PipelineMetricsData(
      timestamp: Date(),
      stageDurations: ["DataProcessing": 1.0],
      memoryUsage: ["DataProcessing": 100],
      validationRates: ["Validator": 0.95],
      errorCounts: ["DataProcessing": 0],
      recordCounts: ["DataProcessing": 1000],
      customValidationResults: nil,
      statisticalMetrics: nil
    )

    // Simulate application logic that works with or without statistical metrics
    func processMetrics(_ data: PipelineMetricsData) -> String {
      var result = "Core metrics: "
      result += "Stages: \(data.stageMetrics.count), "
      result += "Memory: \(data.memoryUsage.values.reduce(0, +)) MB"

      if let stats = data.statisticalMetrics {
        result += ", Enhanced: Training variance: \(stats.trainingLossStats.variance)"
      } else {
        result += ", Enhanced: Not available"
      }

      return result
    }

    let result = processMetrics(oldData)
    XCTAssertTrue(result.contains("Core metrics:"))
    XCTAssertTrue(result.contains("Enhanced: Not available"))
    XCTAssertFalse(result.contains("Training variance:"))
  }
}
