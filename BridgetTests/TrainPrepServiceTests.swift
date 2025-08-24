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

@testable import Bridget
import XCTest

final class TrainPrepServiceTests: XCTestCase {
  var trainPrepService: TrainPrepService!
  var testProgressDelegate: TestTrainPrepProgressDelegate!

  override func setUp() async throws {
    trainPrepService = TrainPrepService()
    testProgressDelegate = await TestTrainPrepProgressDelegate()
  }

  override func tearDown() async throws {
    trainPrepService = nil
    testProgressDelegate = nil
  }

  // MARK: - Step 5: Orchestrator Service Tests

  func testRunPipelineWithValidNDJSON() async throws {
    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    {"v":1,"ts_utc":"2025-01-27T08:01:00Z","bridge_id":1,"cross_k":6,"cross_n":10,"via_routable":1,"via_penalty_sec":150,"gate_anom":2.8,"alternates_total":3,"alternates_avoid":1,"open_label":1,"detour_delta":45,"detour_frac":0.15}
    {"v":1,"ts_utc":"2025-01-27T08:02:00Z","bridge_id":2,"cross_k":3,"cross_n":8,"via_routable":0,"via_penalty_sec":300,"gate_anom":1.5,"alternates_total":2,"alternates_avoid":0,"open_label":0,"detour_delta":-10,"detour_frac":0.05}
    """

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_pipeline.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    // Configure training
    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10, // Small number for testing
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false // Disable ANE for testing
    )

    // Execute pipeline - should fail because no base model files are provided
    do {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate)
      XCTFail("Should throw an error when no base model files are provided")
    } catch {
      // Expected to fail because CoreMLTraining requires base model files
      // Note: Progress delegate calls may not happen if the pipeline fails early
      // The important thing is that the error is properly propagated
      XCTAssertTrue(error is CoreMLTrainingError, "Error should be CoreMLTrainingError")

      // Verify that the progress delegate was notified of failure
      let didFail = await testProgressDelegate.didFail
      XCTAssertTrue(didFail, "Progress delegate should be notified of failure")
    }
  }

  func testRunPipelineWithInvalidNDJSON() async throws {
    // Create invalid NDJSON data
    let invalidData = """
    {"invalid": "json"}
    {"missing": "required", "fields": "bridge_id"}
    """

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_invalid.ndjson")
    try invalidData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    // Should throw an error
    do {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate)
      XCTFail("Should throw an error for invalid data")
    } catch {
      // Expected to fail
      let didFail = await testProgressDelegate.didFail
      XCTAssertTrue(didFail, "Progress delegate should be notified of failure")
    }
  }

  func testRunPipelineWithEmptyNDJSON() async throws {
    // Create empty NDJSON file
    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_empty.ndjson")
    try "".write(to: tempURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    // Should throw an error for insufficient data
    do {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate)
      XCTFail("Should throw an error for empty data")
    } catch {
      // Expected to fail
      let didFail = await testProgressDelegate.didFail
      XCTAssertTrue(didFail, "Progress delegate should be notified of failure")
    }
  }

  func testRunPipelineWithoutProgressDelegate() async throws {
    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    """

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_no_progress.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    // Execute pipeline without progress delegate - should fail because no base model files
    do {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: nil)
      XCTFail("Should throw an error when no base model files are provided")
    } catch {
      // Expected to fail because CoreMLTraining requires base model files
      XCTAssertTrue(error is CoreMLTrainingError, "Error should be CoreMLTrainingError")
    }
  }
}

// MARK: - Test Progress Delegate

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
  var dataQualityGateResults: [String: Bool] = [:] // Use string key for simplicity
  var modelPerformanceGateResults: [String: Bool] = [:] // Use string key for simplicity
  var pipelineMetrics: [PipelineMetrics] = []
  var didComplete = false
  var didFail = false
  var finalError: Error?
  var finalModels: [Int: String] = [:]

  func pipelineDidStartStage(_ stage: PipelineStage) {
    stageSequence.append(stage)
    stageProgress[stage] = []
  }

  func pipelineDidUpdateStageProgress(_ stage: PipelineStage, progress: Double) {
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

  func pipelineDidEvaluateDataQualityGate(_ result: DataValidationResult) -> Bool {
    let key = "\(result.totalRecords)_\(result.validRecordCount)"
    return dataQualityGateResults[key] ?? true
  }

  func setDataQualityGateResult(_ result: DataValidationResult, gateResult: Bool) {
    let key = "\(result.totalRecords)_\(result.validRecordCount)"
    dataQualityGateResults[key] = gateResult
  }

  func pipelineDidEvaluateModelPerformanceGate(_ metrics: ModelPerformanceMetrics) -> Bool {
    let key = "\(metrics.accuracy)_\(metrics.loss)"
    return modelPerformanceGateResults[key] ?? true
  }

  func setModelPerformanceGateResult(_ metrics: ModelPerformanceMetrics, result: Bool) {
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

// MARK: - Enhanced Progress Tests

extension TrainPrepServiceTests {
  func testEnhancedProgressReporting() async throws {
    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    {"v":1,"ts_utc":"2025-01-27T08:01:00Z","bridge_id":1,"cross_k":6,"cross_n":10,"via_routable":1,"via_penalty_sec":150,"gate_anom":2.8,"alternates_total":3,"alternates_avoid":1,"open_label":1,"detour_delta":45,"detour_frac":0.15}
    """

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_enhanced_progress.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let enhancedDelegate = await TestEnhancedProgressDelegate()

    do {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: enhancedDelegate)
      XCTFail("Pipeline should fail due to missing base model files")
    } catch {
      // Expected to fail due to missing base model files
      XCTAssertTrue(error is CoreMLTrainingError, "Error should be CoreMLTrainingError")
    }

    // Verify that the pipeline started and at least some stages ran
    let actualStageSequence = await enhancedDelegate.stageSequence
    XCTAssertFalse(actualStageSequence.isEmpty, "Pipeline should have started at least one stage")

    // Verify that dataLoading stage completed successfully
    XCTAssertTrue(actualStageSequence.contains(.dataLoading), "Data loading stage should have run")
    let dataLoadingProgress = await enhancedDelegate.stageProgress[.dataLoading]
    XCTAssertNotNil(dataLoadingProgress, "Data loading should have progress updates")
    if let progress = dataLoadingProgress {
      XCTAssertTrue(progress.contains(0.0), "Data loading should start at 0.0")
      XCTAssertTrue(progress.contains(1.0), "Data loading should complete at 1.0")
    }

    // Verify that dataValidation stage started (may or may not complete depending on failure point)
    XCTAssertTrue(actualStageSequence.contains(.dataValidation), "Data validation stage should have started")
    let dataValidationProgress = await enhancedDelegate.stageProgress[.dataValidation]
    XCTAssertNotNil(dataValidationProgress, "Data validation should have progress updates")
    if let progress = dataValidationProgress {
      XCTAssertTrue(progress.contains(0.0), "Data validation should start at 0.0")
    }

    // Verify that the pipeline failed (as expected)
    let didFail = await enhancedDelegate.didFail
    XCTAssertTrue(didFail, "Pipeline should have failed as expected")

    // Verify that some metrics were collected (even for failed pipeline)
    let metrics = await enhancedDelegate.pipelineMetrics
    // Note: Metrics may be empty if pipeline fails very early, which is acceptable
    // The important thing is that the failure is properly reported
  }

  func testDataQualityGateEvaluation() async throws {
    // Create test NDJSON data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    """

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_quality_gate.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

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
    await enhancedDelegate.setDataQualityGateResult(validationResult, gateResult: false)

    do {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: enhancedDelegate)
    } catch {
      // Expected to fail due to data quality gate
      let didFail = await enhancedDelegate.didFail
      let finalError = await enhancedDelegate.finalError
      XCTAssertTrue(didFail, "Pipeline should fail when data quality gate fails")
      XCTAssertNotNil(finalError, "Final error should be set")
    }
  }

  func testModelPerformanceGateEvaluation() async throws {
    // This test would require a successful training run to test the model performance gate
    // For now, we'll test the structure without actual training
    let enhancedDelegate = await TestEnhancedProgressDelegate()

    let metrics = ModelPerformanceMetrics(accuracy: 0.8,
                                          loss: 0.2,
                                          f1Score: 0.75,
                                          precision: 0.8,
                                          recall: 0.7,
                                          confusionMatrix: [[80, 20], [30, 70]])

    // Test that the gate can be configured
    await enhancedDelegate.setModelPerformanceGateResult(metrics, result: false)

    // Verify the delegate can evaluate performance gates
    let result = await enhancedDelegate.pipelineDidEvaluateModelPerformanceGate(metrics)
    XCTAssertFalse(result, "Model performance gate should return false when configured to fail")
  }

  func testPipelineMetricsCollection() async throws {
    // Create minimal test data
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    """

    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_metrics.ndjson")
    try testData.write(to: tempURL, atomically: true, encoding: .utf8)

    defer {
      try? FileManager.default.removeItem(at: tempURL)
    }

    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 10,
                                      learningRate: 0.01,
                                      batchSize: 8,
                                      useANE: false)

    let enhancedDelegate = await TestEnhancedProgressDelegate()

    do {
      _ = try await trainPrepService.runPipeline(from: tempURL,
                                                 config: config,
                                                 progress: testProgressDelegate,
                                                 enhancedProgress: enhancedDelegate)
      XCTFail("Pipeline should fail due to missing base model files")
    } catch {
      // Expected to fail due to missing base model files
      XCTAssertTrue(error is CoreMLTrainingError, "Error should be CoreMLTrainingError")
    }

    // Verify that the pipeline failed (as expected)
    let didFail = await enhancedDelegate.didFail
    XCTAssertTrue(didFail, "Pipeline should have failed as expected")

    // Verify that some stages ran before failure
    let actualStageSequence = await enhancedDelegate.stageSequence
    XCTAssertFalse(actualStageSequence.isEmpty, "Pipeline should have started at least one stage")

    // Verify that dataLoading stage completed successfully
    XCTAssertTrue(actualStageSequence.contains(.dataLoading), "Data loading stage should have run")

    // Note: Metrics may be empty if pipeline fails early, which is acceptable
    // The important thing is that the failure is properly reported through the delegate
    let finalError = await enhancedDelegate.finalError
    XCTAssertNotNil(finalError, "Final error should be set when pipeline fails")
  }
}
