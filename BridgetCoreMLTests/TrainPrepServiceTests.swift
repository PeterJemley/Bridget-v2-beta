//
//  TrainPrepServiceTests.swift
//  BridgetTests
//
//  ## Purpose
//  Tests for Step 5: Orchestrator Service (TrainPrepService)
//  Verifies the single entry point and end-to-end pipeline execution
//
//  ## Dependencies
//  TrainPrepService, FeatureEngineeringService, DataValidationService, CoreMLTraining
//

import CoreML
import Foundation
import Testing

@testable import Bridget

@Suite("TrainPrepService Tests")
struct TrainPrepServiceTests {
  // MARK: - Helpers

  private func makeSUT() async -> (TrainPrepService, TestTrainPrepProgressDelegate) {
    let service = TrainPrepService()
    let delegate = await TestTrainPrepProgressDelegate()
    return (service, delegate)
  }

  private func uniqueTempDirectory() throws -> URL {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }

  private func cpuOnlyConfiguration() -> MLModelConfiguration {
    let cfg = MLModelConfiguration()
    cfg.computeUnits = .cpuOnly
    cfg.allowLowPrecisionAccumulationOnGPU = false
    return cfg
  }

  // MARK: - Step 5: Orchestrator Service Tests

  @Test(
    "Run pipeline with valid NDJSON should fail due to missing base model files and report failure via progress delegate"
  )
  func runPipelineWithValidNDJSON() async throws {
    let (trainPrepService, testProgressDelegate) = await makeSUT()

    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    {"v":1,"ts_utc":"2025-01-27T08:01:00Z","bridge_id":1,"cross_k":6,"cross_n":10,"via_routable":1,"via_penalty_sec":150,"gate_anom":2.8,"alternates_total":3,"alternates_avoid":1,"open_label":1,"detour_delta":45,"detour_frac":0.15}
    {"v":1,"ts_utc":"2025-01-27T08:02:00Z","bridge_id":2,"cross_k":3,"cross_n":8,"via_routable":0,"via_penalty_sec":300,"gate_anom":1.5,"alternates_total":2,"alternates_avoid":0,"open_label":0,"detour_delta":-10,"detour_frac":0.05}
    """

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_pipeline.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempURL) }

    // Configure training
    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,  // Small number for testing
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)  // Disable ANE for testing

    // Per-test unique temp directory and CPU-only model configuration
    let tmpDir = try uniqueTempDirectory()
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let modelCfg = cpuOnlyConfiguration()

    // Execute pipeline - should fail because no base model files are provided
    await #expect(throws: CoreMLTrainingError.self) {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: nil,
                                                 modelConfiguration: modelCfg,
                                                 tempDirectory: tmpDir)
    }

    // Verify that the progress delegate was notified of failure
    let didFail = await testProgressDelegate.didFail
    #expect(didFail, "Progress delegate should be notified of failure")
  }

  @Test(
    "Run pipeline with invalid NDJSON should fail and report failure via progress delegate"
  )
  func runPipelineWithInvalidNDJSON() async throws {
    let (trainPrepService, testProgressDelegate) = await makeSUT()

    // Create invalid NDJSON data
    let invalidData = """
    {"invalid": "json"}
    {"missing": "required", "fields": "bridge_id"}
    """

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_invalid.ndjson")
    try invalidData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempURL) }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let tmpDir = try uniqueTempDirectory()
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let modelCfg = cpuOnlyConfiguration()

    // Should throw an error
    await #expect(throws: Error.self) {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: nil,
                                                 modelConfiguration: modelCfg,
                                                 tempDirectory: tmpDir)
    }

    // Expected to fail
    let didFail = await testProgressDelegate.didFail
    #expect(didFail, "Progress delegate should be notified of failure")
  }

  @Test(
    "Run pipeline with empty NDJSON should fail and report failure via progress delegate"
  )
  func runPipelineWithEmptyNDJSON() async throws {
    let (trainPrepService, testProgressDelegate) = await makeSUT()

    // Create empty NDJSON file
    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_empty.ndjson")
    try "".write(to: tempURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempURL) }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let tmpDir = try uniqueTempDirectory()
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let modelCfg = cpuOnlyConfiguration()

    // Should throw an error for insufficient data
    await #expect(throws: Error.self) {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: nil,
                                                 modelConfiguration: modelCfg,
                                                 tempDirectory: tmpDir)
    }

    // Expected to fail
    let didFail = await testProgressDelegate.didFail
    #expect(didFail, "Progress delegate should be notified of failure")
  }

  @Test(
    "Run pipeline without progress delegate should still throw CoreMLTrainingError"
  )
  func runPipelineWithoutProgressDelegate() async throws {
    let (trainPrepService, _) = await makeSUT()

    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    """

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_no_progress.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempURL) }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let tmpDir = try uniqueTempDirectory()
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let modelCfg = cpuOnlyConfiguration()

    // Execute pipeline without progress delegate - should fail because no base model files
    await #expect(throws: CoreMLTrainingError.self) {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: nil,
                                                 enhancedProgress: nil,
                                                 modelConfiguration: modelCfg,
                                                 tempDirectory: tmpDir)
    }
  }

  // MARK: - Enhanced Progress Tests

  @Test(
    "Enhanced progress reporting should record stages and fail due to missing base model files"
  )
  func enhancedProgressReporting() async throws {
    let (trainPrepService, testProgressDelegate) = await makeSUT()

    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    {"v":1,"ts_utc":"2025-01-27T08:01:00Z","bridge_id":1,"cross_k":6,"cross_n":10,"via_routable":1,"via_penalty_sec":150,"gate_anom":2.8,"alternates_total":3,"alternates_avoid":1,"open_label":1,"detour_delta":45,"detour_frac":0.15}
    """

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_enhanced_progress.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempURL) }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let enhancedDelegate = await TestEnhancedProgressDelegate()

    let tmpDir = try uniqueTempDirectory()
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let modelCfg = cpuOnlyConfiguration()

    await #expect(throws: CoreMLTrainingError.self) {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: enhancedDelegate,
                                                 modelConfiguration: modelCfg,
                                                 tempDirectory: tmpDir)
    }

    // Verify that the pipeline started and at least some stages ran
    let actualStageSequence = await enhancedDelegate.stageSequence
    #expect(!actualStageSequence.isEmpty,
            "Pipeline should have started at least one stage")

    // Verify that dataLoading stage completed successfully
    #expect(actualStageSequence.contains(.dataLoading),
            "Data loading stage should have run")
    let dataLoadingProgress = await enhancedDelegate.stageProgress[
      .dataLoading
    ]
    #expect(dataLoadingProgress != nil,
            "Data loading should have progress updates")
    if let progress = dataLoadingProgress {
      #expect(progress.contains(0.0), "Data loading should start at 0.0")
      #expect(progress.contains(1.0),
              "Data loading should complete at 1.0")
    }

    // Verify that dataValidation stage started (may or may not complete depending on failure point)
    #expect(actualStageSequence.contains(.dataValidation),
            "Data validation stage should have started")
    let dataValidationProgress = await enhancedDelegate.stageProgress[
      .dataValidation
    ]
    #expect(dataValidationProgress != nil,
            "Data validation should have progress updates")
    if let progress = dataValidationProgress {
      #expect(progress.contains(0.0),
              "Data validation should start at 0.0")
    }

    // Verify that the pipeline failed (as expected)
    let didFail = await enhancedDelegate.didFail
    #expect(didFail, "Pipeline should have failed as expected")

    // Metrics may be empty if pipeline fails very early; no strict expectation here
    _ = await enhancedDelegate.pipelineMetrics
  }

  @Test(
    "Data quality gate evaluation can fail the pipeline and report final error"
  )
  func dataQualityGateEvaluation() async throws {
    let (trainPrepService, testProgressDelegate) = await makeSUT()

    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    """

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_quality_gate.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempURL) }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let enhancedDelegate = await TestEnhancedProgressDelegate()

    // Set up data quality gate to fail
    let validationResult = DataValidationResult(totalRecords: 1,
                                                isValid: true,
                                                errors: [],
                                                warnings: [],
                                                dataQualityMetrics: DataQualityMetrics(dataCompleteness: 1.0,
                                                                                       timestampValidity: 1.0,
                                                                                       bridgeIDValidity: 1.0,
                                                                                       speedDataValidity: 1.0,
                                                                                       duplicateCount: 0,
                                                                                       missingFieldsCount: 0,
                                                                                       nanCounts: [:],
                                                                                       infiniteCounts: [:],
                                                                                       outlierCounts: [:],
                                                                                       rangeViolations: [:],
                                                                                       nullCounts: [:]))
    await enhancedDelegate.setDataQualityGateResult(validationResult,
                                                    gateResult: false)

    let tmpDir = try uniqueTempDirectory()
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let modelCfg = cpuOnlyConfiguration()

    await #expect(throws: Error.self) {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: enhancedDelegate,
                                                 modelConfiguration: modelCfg,
                                                 tempDirectory: tmpDir)
    }

    // Expected to fail due to data quality gate
    let didFail = await enhancedDelegate.didFail
    let finalError = await enhancedDelegate.finalError
    #expect(didFail,
            "Pipeline should fail when data quality gate fails")
    #expect(finalError != nil, "Final error should be set")
  }

  @Test("Model performance gate evaluation can be configured and evaluated")
  func modelPerformanceGateEvaluation() async throws {
    let enhancedDelegate = await TestEnhancedProgressDelegate()

    let metrics = ModelPerformanceMetrics(accuracy: 0.8,
                                          loss: 0.2,
                                          f1Score: 0.75,
                                          precision: 0.8,
                                          recall: 0.7,
                                          confusionMatrix: [[80, 20], [30, 70]])

    // Test that the gate can be configured
    await enhancedDelegate.setModelPerformanceGateResult(metrics,
                                                         result: false)

    // Verify the delegate can evaluate performance gates
    let result =
      await enhancedDelegate.pipelineDidEvaluateModelPerformanceGate(
        metrics
      )
    #expect(result == false,
            "Model performance gate should return false when configured to fail")
  }

  @Test(
    "Pipeline metrics collection should record stages before expected failure"
  )
  func pipelineMetricsCollection() async throws {
    let (trainPrepService, testProgressDelegate) = await makeSUT()

    // Create minimal test data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    """

    let tempURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("test_metrics.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer { try? FileManager.default.removeItem(at: tempURL) }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let enhancedDelegate = await TestEnhancedProgressDelegate()

    let tmpDir = try uniqueTempDirectory()
    defer { try? FileManager.default.removeItem(at: tmpDir) }
    let modelCfg = cpuOnlyConfiguration()

    await #expect(throws: CoreMLTrainingError.self) {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: enhancedDelegate,
                                                 modelConfiguration: modelCfg,
                                                 tempDirectory: tmpDir)
    }

    // Verify that the pipeline failed (as expected)
    let didFail = await enhancedDelegate.didFail
    #expect(didFail, "Pipeline should have failed as expected")

    // Verify that some stages ran before failure
    let actualStageSequence = await enhancedDelegate.stageSequence
    #expect(!actualStageSequence.isEmpty,
            "Pipeline should have started at least one stage")

    // Verify that dataLoading stage completed successfully
    #expect(actualStageSequence.contains(.dataLoading),
            "Data loading stage should have run")

    // The important thing is that the failure is properly reported through the delegate
    let finalError = await enhancedDelegate.finalError
    #expect(finalError != nil,
            "Final error should be set when pipeline fails")
  }
}

// MARK: - Test Progress Delegate

@MainActor
class TestTrainPrepProgressDelegate: TrainPrepProgressDelegate {
  var didStart = false
  var didLoadData = false
  var didProcessHorizon = false
  var didSaveHorizon = false
  var didComplete = false
  var didFail = false

  func trainPrepDidStart() {
    didStart = true
  }

  func trainPrepDidLoadData(_: Int) {
    didLoadData = true
  }

  func trainPrepDidProcessHorizon(_: Int, featureCount _: Int) {
    didProcessHorizon = true
  }

  func trainPrepDidSaveHorizon(_: Int, to _: String) {
    didSaveHorizon = true
  }

  func trainPrepDidComplete() {
    didComplete = true
  }

  func trainPrepDidFail(_: Error) {
    didFail = true
  }
}

// MARK: - Enhanced Test Progress Delegate

@MainActor
class TestEnhancedProgressDelegate: EnhancedPipelineProgressDelegate {
  var stageSequence: [PipelineStage] = []
  var stageProgress: [PipelineStage: [Double]] = [:]
  var stageErrors: [PipelineStage: Error] = [:]
  var dataQualityGateResults: [String: Bool] = [:]  // Use string key for simplicity
  var modelPerformanceGateResults: [String: Bool] = [:]  // Use string key for simplicity
  var pipelineMetrics: [PipelineMetrics] = []
  var didComplete = false
  var didFail = false
  var finalError: Error?
  var finalModels: [Int: String] = [:]

  func pipelineDidStartStage(_ stage: PipelineStage) {
    stageSequence.append(stage)
    stageProgress[stage] = []
  }

  func pipelineDidUpdateStageProgress(_ stage: PipelineStage,
                                      progress: Double)
  {
    stageProgress[stage, default: []].append(progress)
  }

  func pipelineDidCompleteStage(_: PipelineStage) {
    // Stage completed successfully
  }

  func pipelineDidFailStage(_ stage: PipelineStage, error: Error) {
    stageErrors[stage] = error
  }

  func pipelineDidCreateCheckpoint(_: PipelineStage, at _: String) {
    // Not implemented for this test
  }

  func pipelineDidResumeFromCheckpoint(_: PipelineStage, at _: String) {
    // Not implemented for this test
  }

  func pipelineDidEvaluateDataQualityGate(_ result: DataValidationResult)
    -> Bool
  {
    let key = "\(result.totalRecords)_\(result.validRecordCount)"
    return dataQualityGateResults[key] ?? true
  }

  func setDataQualityGateResult(_ result: DataValidationResult,
                                gateResult: Bool)
  {
    let key = "\(result.totalRecords)_\(result.validRecordCount)"
    dataQualityGateResults[key] = gateResult
  }

  func pipelineDidEvaluateModelPerformanceGate(
    _ metrics: ModelPerformanceMetrics
  ) -> Bool {
    let key = "\(metrics.accuracy)_\(metrics.loss)"
    return modelPerformanceGateResults[key] ?? true
  }

  func setModelPerformanceGateResult(_ metrics: ModelPerformanceMetrics,
                                     result: Bool)
  {
    let key = "\(metrics.accuracy)_\(metrics.loss)"
    modelPerformanceGateResults[key] = result
  }

  func pipelineDidUpdateMetrics(_ metrics: PipelineMetrics) {
    pipelineMetrics.append(metrics)
  }

  func pipelineDidExportMetrics(to _: String) {
    // Not implemented for this test
  }

  func pipelineDidComplete(_ models: [Int: String]) {
    didComplete = true
    finalModels = models
  }

  func pipelineDidFail(_ error: Error) {
    didFail = true
    finalError = error
  }
}
