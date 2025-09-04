//
//  PipelineMetricsModelsTests.swift
//  BridgetTests
//
//  Purpose: Test PipelineStageMetric and PipelineMetricsData models
//  Dependencies: Swift Testing framework, PipelineMetricsModels
//  Integration Points:
//    - Tests data model logic and computed properties
//    - Validates JSON decoding with bridgeDecoder
//    - Tests edge cases and error conditions
//

import Foundation
import SwiftUI
import Testing

@testable import Bridget

@Suite("Pipeline Metrics Models Tests")
struct PipelineMetricsModelsTests {
  // MARK: - PipelineStageMetric Tests

  @Test("PipelineStageMetric initialization and properties")
  func pipelineStageMetricInitialization() throws {
    let metric = PipelineStageMetric(stage: "dataLoading",
                                     duration: 2.5,
                                     memory: 128,
                                     errorCount: 0,
                                     recordCount: 10000,
                                     validationRate: 1.0)

    #expect(metric.id == "dataLoading")
    #expect(metric.stage == "dataLoading")
    #expect(metric.duration == 2.5)
    #expect(metric.memory == 128)
    #expect(metric.errorCount == 0)
    #expect(metric.recordCount == 10000)
    #expect(metric.validationRate == 1.0)
  }

  @Test("PipelineStageMetric displayName mapping")
  func displayNameMapping() throws {
    let testCases = [
      ("dataLoading", "Data Loading"),
      ("dataValidation", "Data Validation"),
      ("featureEngineering", "Feature Engineering"),
      ("mlMultiArrayConversion", "ML Array Conversion"),
      ("modelTraining", "Model Training"),
      ("modelValidation", "Model Validation"),
      ("artifactExport", "Artifact Export"),
      ("unknownStage", "Unknownstage"), // Should capitalize
    ]

    for (stage, expectedDisplay) in testCases {
      let metric = PipelineStageMetric(stage: stage,
                                       duration: 1.0,
                                       memory: 100,
                                       errorCount: 0,
                                       recordCount: 1000,
                                       validationRate: 1.0)
      #expect(metric.displayName == expectedDisplay)
    }
  }

  @Test("PipelineStageMetric statusColor logic")
  func statusColorLogic() throws {
    // Test error state (red)
    let errorMetric = PipelineStageMetric(stage: "test",
                                          duration: 1.0,
                                          memory: 100,
                                          errorCount: 1,
                                          recordCount: 1000,
                                          validationRate: 1.0)
    #expect(errorMetric.statusColor == .red)

    // Test warning state (orange) - low validation rate
    let warningMetric = PipelineStageMetric(stage: "test",
                                            duration: 1.0,
                                            memory: 100,
                                            errorCount: 0,
                                            recordCount: 1000,
                                            validationRate: 0.94 // Below 0.95 threshold
    )
    #expect(warningMetric.statusColor == .orange)

    // Test success state (green) - no errors, good validation
    let successMetric = PipelineStageMetric(stage: "test",
                                            duration: 1.0,
                                            memory: 100,
                                            errorCount: 0,
                                            recordCount: 1000,
                                            validationRate: 0.95 // At threshold
    )
    #expect(successMetric.statusColor == .green)
  }

  @Test("PipelineStageMetric equality and hashing")
  func equalityAndHashing() throws {
    let metric1 = PipelineStageMetric(stage: "dataLoading",
                                      duration: 2.5,
                                      memory: 128,
                                      errorCount: 0,
                                      recordCount: 10000,
                                      validationRate: 1.0)

    let metric2 = PipelineStageMetric(stage: "dataLoading",
                                      duration: 2.5,
                                      memory: 128,
                                      errorCount: 0,
                                      recordCount: 10000,
                                      validationRate: 1.0)

    let metric3 = PipelineStageMetric(stage: "dataValidation",
                                      duration: 2.5,
                                      memory: 128,
                                      errorCount: 0,
                                      recordCount: 10000,
                                      validationRate: 1.0)

    #expect(metric1 == metric2)
    #expect(metric1 != metric3)
    #expect(metric1.hashValue == metric2.hashValue)
    #expect(metric1.hashValue != metric3.hashValue)
  }

  // MARK: - PipelineMetricsData Tests

  @Test("PipelineMetricsData initialization")
  func pipelineMetricsDataInitialization() throws {
    let data = PipelineMetricsData(timestamp: Date(),
                                   stageDurations: ["dataLoading": 2.5, "dataValidation": 1.8],
                                   memoryUsage: ["dataLoading": 128, "dataValidation": 256],
                                   validationRates: ["dataLoading": 1.0, "dataValidation": 0.98],
                                   errorCounts: ["dataLoading": 0, "dataValidation": 2],
                                   recordCounts: ["dataLoading": 10000, "dataValidation": 10000],
                                   customValidationResults: ["test": true],
                                   statisticalMetrics: nil)

    #expect(data.stageDurations.count == 2)
    #expect(data.memoryUsage.count == 2)
    #expect(data.validationRates.count == 2)
    #expect(data.errorCounts.count == 2)
    #expect(data.recordCounts.count == 2)
    #expect(data.customValidationResults?.count == 1)
    #expect(data.statisticalMetrics == nil)
  }

  @Test("PipelineMetricsData stageMetrics computed property")
  func stageMetricsComputedProperty() throws {
    let data = PipelineMetricsData(timestamp: Date(),
                                   stageDurations: [
                                     "dataLoading": 2.5,
                                     "dataValidation": 1.8,
                                     "featureEngineering": 15.2,
                                   ],
                                   memoryUsage: [
                                     "dataLoading": 128,
                                     "dataValidation": 256,
                                     "featureEngineering": 1024,
                                   ],
                                   validationRates: [
                                     "dataLoading": 1.0,
                                     "dataValidation": 0.98,
                                     "featureEngineering": 0.95,
                                   ],
                                   errorCounts: [
                                     "dataLoading": 0,
                                     "dataValidation": 2,
                                     "featureEngineering": 5,
                                   ],
                                   recordCounts: [
                                     "dataLoading": 10000,
                                     "dataValidation": 10000,
                                     "featureEngineering": 9800,
                                   ],
                                   customValidationResults: nil,
                                   statisticalMetrics: nil)

    let metrics = data.stageMetrics
    #expect(metrics.count == 3)

    // Should be sorted by duration descending
    #expect(metrics[0].stage == "featureEngineering")
    #expect(metrics[1].stage == "dataLoading")
    #expect(metrics[2].stage == "dataValidation")

    // Verify all properties are correctly mapped
    let featureEngineering = metrics[0]
    #expect(featureEngineering.duration == 15.2)
    #expect(featureEngineering.memory == 1024)
    #expect(featureEngineering.errorCount == 5)
    #expect(featureEngineering.recordCount == 9800)
    #expect(featureEngineering.validationRate == 0.95)
  }

  @Test("PipelineMetricsData computed totals")
  func computedTotals() throws {
    let data = PipelineMetricsData(timestamp: Date(),
                                   stageDurations: ["stage1": 10.0, "stage2": 5.0, "stage3": 15.0],
                                   memoryUsage: ["stage1": 100, "stage2": 200, "stage3": 300],
                                   validationRates: ["stage1": 1.0, "stage2": 0.9, "stage3": 0.95],
                                   errorCounts: ["stage1": 0, "stage2": 1, "stage3": 0],
                                   recordCounts: ["stage1": 1000, "stage2": 1000, "stage3": 1000],
                                   customValidationResults: nil,
                                   statisticalMetrics: nil)

    #expect(data.totalDuration == 30.0)
    #expect(data.totalMemory == 600)
    #expect(abs(data.averageValidationRate - 0.95) < 0.001) // ~0.95
  }

  @Test("PipelineMetricsData averageValidationRate edge cases")
  func averageValidationRateEdgeCases() throws {
    // Empty validation rates should return 1.0
    let emptyData = PipelineMetricsData(timestamp: Date(),
                                        stageDurations: [:],
                                        memoryUsage: [:],
                                        validationRates: [:],
                                        errorCounts: [:],
                                        recordCounts: [:],
                                        customValidationResults: nil,
                                        statisticalMetrics: nil)
    #expect(emptyData.averageValidationRate == 1.0)

    // Single validation rate
    let singleData = PipelineMetricsData(timestamp: Date(),
                                         stageDurations: ["stage1": 1.0],
                                         memoryUsage: ["stage1": 100],
                                         validationRates: ["stage1": 0.8],
                                         errorCounts: ["stage1": 0],
                                         recordCounts: ["stage1": 1000],
                                         customValidationResults: nil,
                                         statisticalMetrics: nil)
    #expect(singleData.averageValidationRate == 0.8)
  }

  @Test("PipelineMetricsData topStagesByDuration")
  func testTopStagesByDuration() throws {
    let data = PipelineMetricsData(timestamp: Date(),
                                   stageDurations: [
                                     "stage1": 10.0,
                                     "stage2": 5.0,
                                     "stage3": 15.0,
                                     "stage4": 2.0,
                                     "stage5": 8.0,
                                   ],
                                   memoryUsage: [
                                     "stage1": 100,
                                     "stage2": 200,
                                     "stage3": 300,
                                     "stage4": 50,
                                     "stage5": 150,
                                   ],
                                   validationRates: [
                                     "stage1": 1.0,
                                     "stage2": 0.9,
                                     "stage3": 0.95,
                                     "stage4": 1.0,
                                     "stage5": 0.98,
                                   ],
                                   errorCounts: [
                                     "stage1": 0,
                                     "stage2": 1,
                                     "stage3": 0,
                                     "stage4": 0,
                                     "stage5": 0,
                                   ],
                                   recordCounts: [
                                     "stage1": 1000,
                                     "stage2": 1000,
                                     "stage3": 1000,
                                     "stage4": 1000,
                                     "stage5": 1000,
                                   ],
                                   customValidationResults: nil,
                                   statisticalMetrics: nil)

    let top3 = data.topStagesByDuration(limit: 3)
    #expect(top3.count == 3)
    #expect(top3[0].stage == "stage3") // 15.0
    #expect(top3[1].stage == "stage1") // 10.0
    #expect(top3[2].stage == "stage5") // 8.0

    let top1 = data.topStagesByDuration(limit: 1)
    #expect(top1.count == 1)
    #expect(top1[0].stage == "stage3")
  }

  @Test("PipelineMetricsData topStagesByMemory")
  func testTopStagesByMemory() throws {
    let data = PipelineMetricsData(timestamp: Date(),
                                   stageDurations: [
                                     "stage1": 10.0,
                                     "stage2": 5.0,
                                     "stage3": 15.0,
                                   ],
                                   memoryUsage: [
                                     "stage1": 100,
                                     "stage2": 500,
                                     "stage3": 200,
                                   ],
                                   validationRates: [
                                     "stage1": 1.0,
                                     "stage2": 0.9,
                                     "stage3": 0.95,
                                   ],
                                   errorCounts: [
                                     "stage1": 0,
                                     "stage2": 1,
                                     "stage3": 0,
                                   ],
                                   recordCounts: [
                                     "stage1": 1000,
                                     "stage2": 1000,
                                     "stage3": 1000,
                                   ],
                                   customValidationResults: nil,
                                   statisticalMetrics: nil)

    let top2 = data.topStagesByMemory(limit: 2)
    #expect(top2.count == 2)
    #expect(top2[0].stage == "stage2") // 500
    #expect(top2[1].stage == "stage3") // 200
  }

  @Test("PipelineMetricsData Codable conformance")
  func codableConformance() throws {
    let originalData = PipelineMetricsData(timestamp: Date(),
                                           stageDurations: ["dataLoading": 2.5],
                                           memoryUsage: ["dataLoading": 128],
                                           validationRates: ["dataLoading": 1.0],
                                           errorCounts: ["dataLoading": 0],
                                           recordCounts: ["dataLoading": 10000],
                                           customValidationResults: ["test": true],
                                           statisticalMetrics: nil)

    let encoder = JSONEncoder()
    let decoder = JSONDecoder.bridgeDecoder()

    let jsonData = try encoder.encode(originalData)
    let decodedData = try decoder.decode(PipelineMetricsData.self, from: jsonData)

    #expect(decodedData.stageDurations == originalData.stageDurations)
    #expect(decodedData.memoryUsage == originalData.memoryUsage)
    #expect(decodedData.validationRates == originalData.validationRates)
    #expect(decodedData.errorCounts == originalData.errorCounts)
    #expect(decodedData.recordCounts == originalData.recordCounts)
    #expect(decodedData.customValidationResults == originalData.customValidationResults)
  }
}
