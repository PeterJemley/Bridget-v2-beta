//
//  BackwardCompatibilityTests.swift
//  BridgetTests
//
//  Backward compatibility validations for metrics and APIs
//

import Foundation
import Testing

@testable import Bridget

@Suite("Backward Compatibility Tests")
struct BackwardCompatibilityTests {
  // MARK: - PipelineMetricsData Backward Compatibility

  @Test("Old-style PipelineMetricsData still works")
  func pipelineMetricsDataBackwardCompatibility() {
    let oldData = PipelineMetricsData(timestamp: Date(),
                                      stageDurations: ["DataProcessing": 1.0],
                                      memoryUsage: ["DataProcessing": 100],
                                      validationRates: ["Validator": 0.95],
                                      errorCounts: ["DataProcessing": 0],
                                      recordCounts: ["DataProcessing": 1000],
                                      customValidationResults: nil,
                                      statisticalMetrics: nil)

    #expect(oldData.stageDurations["DataProcessing"] == 1.0)
    #expect(oldData.memoryUsage["DataProcessing"] == 100)
    #expect(oldData.validationRates["Validator"] == 0.95)
    #expect(oldData.errorCounts["DataProcessing"] == 0)
    #expect(oldData.recordCounts["DataProcessing"] == 1000)
    #expect(oldData.customValidationResults == nil)

    // new field is nil
    #expect(oldData.statisticalMetrics == nil)

    // computed properties
    #expect(oldData.stageMetrics.count == 1)
    #expect(oldData.stageMetrics.first?.stage == "DataProcessing")
  }

  @Test("New-style PipelineMetricsData with statistical metrics works")
  func pipelineMetricsDataWithNewFeatures() {
    let statisticalMetrics = StatisticalTrainingMetrics(trainingLossStats: ETASummary(mean: 0.1, variance: 0.01, min: 0.05, max: 0.15),
                                                        validationLossStats: ETASummary(mean: 0.12, variance: 0.015, min: 0.06, max: 0.18),
                                                        predictionAccuracyStats: ETASummary(mean: 0.85, variance: 0.001, min: 0.82, max: 0.88),
                                                        etaPredictionVariance: ETASummary(mean: 120.0, variance: 25.0, min: 90.0, max: 150.0),
                                                        performanceConfidenceIntervals: PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
                                                                                                                       f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
                                                                                                                       meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)),
                                                        errorDistribution: ErrorDistributionMetrics(absoluteErrorStats: ETASummary(mean: 0.05, variance: 0.002, min: 0.02, max: 0.08),
                                                                                                    relativeErrorStats: ETASummary(mean: 0.12, variance: 0.005, min: 0.08, max: 0.16),
                                                                                                    withinOneStdDev: 68.2,
                                                                                                    withinTwoStdDev: 95.4))

    let newData = PipelineMetricsData(timestamp: Date(),
                                      stageDurations: ["DataProcessing": 1.0],
                                      memoryUsage: ["DataProcessing": 100],
                                      validationRates: ["Validator": 0.95],
                                      errorCounts: ["DataProcessing": 0],
                                      recordCounts: ["DataProcessing": 1000],
                                      customValidationResults: nil,
                                      statisticalMetrics: statisticalMetrics)

    #expect(newData.stageDurations["DataProcessing"] == 1.0)
    #expect(newData.memoryUsage["DataProcessing"] == 100)
    #expect(newData.validationRates["Validator"] == 0.95)
    #expect(newData.errorCounts["DataProcessing"] == 0)
    #expect(newData.recordCounts["DataProcessing"] == 1000)
    #expect(newData.customValidationResults == nil)

    #expect(newData.statisticalMetrics != nil)
    #expect(abs((newData.statisticalMetrics?.trainingLossStats.mean ?? 0.0) - 0.1) < 0.001)
    #expect(abs((newData.statisticalMetrics?.predictionAccuracyStats.mean ?? 0.0) - 0.85) < 0.001)

    #expect(newData.stageMetrics.count == 1)
    #expect(newData.stageMetrics.first?.stage == "DataProcessing")
  }

  // MARK: - CoreMLTraining Backward Compatibility

  @Test("CoreMLTraining basic API remains constructible and helpers return nil for empty inputs")
  func coreMLTrainingBackwardCompatibility() {
    let coreMLTraining = CoreMLTraining(config: .validation)
    #expect(coreMLTraining != nil)

    let emptyLossTrend: [Double] = []
    let emptyAccuracyTrend: [Double] = []

    #expect(
      CoreMLTraining(config: .validation).computeTrainingLossVariance(lossTrend: emptyLossTrend)
        == nil)
    #expect(
      CoreMLTraining(config: .validation).computeValidationAccuracyVariance(
        accuracyTrend: emptyAccuracyTrend) == nil)
  }

  // MARK: - UI Backward Compatibility

  @Test("UI-facing data structures handle nil statistical metrics")
  func uiBackwardCompatibility() {
    let oldData = PipelineMetricsData(timestamp: Date(),
                                      stageDurations: ["DataProcessing": 1.0],
                                      memoryUsage: ["DataProcessing": 100],
                                      validationRates: ["Validator": 0.95],
                                      errorCounts: ["DataProcessing": 0],
                                      recordCounts: ["DataProcessing": 1000],
                                      customValidationResults: nil,
                                      statisticalMetrics: nil)

    #expect(oldData.statisticalMetrics == nil)
    #expect(oldData.stageMetrics.count == 1)
  }

  // MARK: - Serialization Backward Compatibility

  @Test("Old data encodes/decodes without statistical metrics")
  func serializationBackwardCompatibility() throws {
    let oldData = PipelineMetricsData(timestamp: Date(),
                                      stageDurations: ["DataProcessing": 1.0],
                                      memoryUsage: ["DataProcessing": 100],
                                      validationRates: ["Validator": 0.95],
                                      errorCounts: ["DataProcessing": 0],
                                      recordCounts: ["DataProcessing": 1000],
                                      customValidationResults: nil,
                                      statisticalMetrics: nil)

    let encoder = JSONEncoder()
    let data = try encoder.encode(oldData)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(PipelineMetricsData.self, from: data)

    #expect(
      abs(oldData.timestamp.timeIntervalSince1970 - decoded.timestamp.timeIntervalSince1970) <= 1.0)
    #expect(oldData.stageDurations == decoded.stageDurations)
    #expect(oldData.memoryUsage == decoded.memoryUsage)
    #expect(oldData.validationRates == decoded.validationRates)
    #expect(oldData.errorCounts == decoded.errorCounts)
    #expect(oldData.recordCounts == decoded.recordCounts)
    #expect(oldData.customValidationResults == decoded.customValidationResults)
    #expect(decoded.statisticalMetrics == nil)
  }

  @Test("New data with statistical metrics encodes/decodes")
  func serializationWithNewFeatures() throws {
    let statisticalMetrics = StatisticalTrainingMetrics(trainingLossStats: ETASummary(mean: 0.1, variance: 0.01, min: 0.05, max: 0.15),
                                                        validationLossStats: ETASummary(mean: 0.12, variance: 0.015, min: 0.06, max: 0.18),
                                                        predictionAccuracyStats: ETASummary(mean: 0.85, variance: 0.001, min: 0.82, max: 0.88),
                                                        etaPredictionVariance: ETASummary(mean: 120.0, variance: 25.0, min: 90.0, max: 150.0),
                                                        performanceConfidenceIntervals: PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: 0.82, upper: 0.88),
                                                                                                                       f1Score95CI: ConfidenceInterval(lower: 0.80, upper: 0.90),
                                                                                                                       meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)),
                                                        errorDistribution: ErrorDistributionMetrics(absoluteErrorStats: ETASummary(mean: 0.05, variance: 0.002, min: 0.02, max: 0.08),
                                                                                                    relativeErrorStats: ETASummary(mean: 0.12, variance: 0.005, min: 0.08, max: 0.16),
                                                                                                    withinOneStdDev: 68.2,
                                                                                                    withinTwoStdDev: 95.4))

    let newData = PipelineMetricsData(timestamp: Date(),
                                      stageDurations: ["DataProcessing": 1.0],
                                      memoryUsage: ["DataProcessing": 100],
                                      validationRates: ["Validator": 0.95],
                                      errorCounts: ["DataProcessing": 0],
                                      recordCounts: ["DataProcessing": 1000],
                                      customValidationResults: nil,
                                      statisticalMetrics: statisticalMetrics)

    let encoder = JSONEncoder()
    let data = try encoder.encode(newData)
    let decoder = JSONDecoder()
    let decoded = try decoder.decode(PipelineMetricsData.self, from: data)

    #expect(
      abs(newData.timestamp.timeIntervalSince1970 - decoded.timestamp.timeIntervalSince1970) <= 1.0)
    #expect(newData.stageDurations == decoded.stageDurations)
    #expect(newData.memoryUsage == decoded.memoryUsage)
    #expect(newData.validationRates == decoded.validationRates)
    #expect(newData.errorCounts == decoded.errorCounts)
    #expect(newData.recordCounts == decoded.recordCounts)
    #expect(newData.customValidationResults == decoded.customValidationResults)
    #expect(decoded.statisticalMetrics != nil)
    #expect(abs((decoded.statisticalMetrics?.trainingLossStats.mean ?? 0.0) - 0.1) < 0.001)
    #expect(abs((decoded.statisticalMetrics?.predictionAccuracyStats.mean ?? 0.0) - 0.85) < 0.001)
  }

  // MARK: - API Evolution Tests

  @Test("Optional feature handling and graceful degradation")
  func optionalFeatureHandling() {
    let oldData = PipelineMetricsData(timestamp: Date(),
                                      stageDurations: ["DataProcessing": 1.0],
                                      memoryUsage: ["DataProcessing": 100],
                                      validationRates: ["Validator": 0.95],
                                      errorCounts: ["DataProcessing": 0],
                                      recordCounts: ["DataProcessing": 1000],
                                      customValidationResults: nil,
                                      statisticalMetrics: nil)

    // Safe access pattern
    if oldData.statisticalMetrics != nil {
      Issue.record("Statistical metrics should be nil for old data")
    } else {
      #expect(true)
    }

    // Core functionality still works without statistical metrics
    #expect(oldData.stageMetrics.count == 1)
  }

  @Test("Graceful degradation in processing function")
  func gracefulDegradation() {
    let oldData = PipelineMetricsData(timestamp: Date(),
                                      stageDurations: ["DataProcessing": 1.0],
                                      memoryUsage: ["DataProcessing": 100],
                                      validationRates: ["Validator": 0.95],
                                      errorCounts: ["DataProcessing": 0],
                                      recordCounts: ["DataProcessing": 1000],
                                      customValidationResults: nil,
                                      statisticalMetrics: nil)

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
    #expect(result.contains("Core metrics:"))
    #expect(result.contains("Enhanced: Not available"))
    #expect(!result.contains("Training variance:"))
  }
}
