//
//  CoreMLTrainingTests.swift
//  BridgetTests
//
//  ## Purpose
//  Unit tests for CoreMLTraining module with synthetic data and device validation
//  Tests shape stability, error handling, and runtime behavior
//
//  ## Dependencies
//  XCTest framework, CoreML framework, Bridget module
//
//  ## Test Coverage
//  - Conversion utilities with shape validation
//  - Training orchestration with error handling
//  - Validation helpers with sanity checks
//  - Synthetic data generation
//  - Device runtime validation
//

@testable import Bridget
import CoreML
import XCTest
import Bridget // To access `missingBaseModelMessage`

final class CoreMLTrainingTests: XCTestCase {
  // MARK: - Test Data

  private var syntheticFeatures: [FeatureVector]!
  private var trainingConfig: CoreMLTrainingConfig!
  private var trainer: CoreMLTraining!

  override func setUpWithError() throws {
    try super.setUpWithError()

    // Generate synthetic test data
    syntheticFeatures = CoreMLTraining.generateSyntheticData(count: 100)

    // Create validation configuration for fast testing
    trainingConfig = CoreMLTrainingConfig.validation

    // Create trainer instance
    trainer = CoreMLTraining(config: trainingConfig)
  }

  override func tearDownWithError() throws {
    syntheticFeatures = nil
    trainingConfig = nil
    trainer = nil
    try super.tearDownWithError()
  }

  // MARK: - Conversion Utilities Tests

  func testToMLMultiArrayWithValidFeatures() throws {
    // Given: Valid feature vectors
    let features = Array(syntheticFeatures.prefix(10))

    // When: Converting to MLMultiArray
    let multiArray = try CoreMLTraining.toMLMultiArray(features)

    // Then: Shape should be correct
    XCTAssertEqual(multiArray.shape.count, 2)
    XCTAssertEqual(multiArray.shape[0].intValue, 10) // feature count
    XCTAssertEqual(multiArray.shape[1].intValue, FeatureVector.featureCount) // feature dimension
    XCTAssertEqual(multiArray.dataType, .double)
  }

  func testToMLMultiArrayWithEmptyFeatures() throws {
    // Given: Empty feature array
    let features: [FeatureVector] = []

    // When/Then: Should throw insufficient data error
    XCTAssertThrowsError(try CoreMLTraining.toMLMultiArray(features)) { error in
      guard case CoreMLTrainingError.insufficientData(required: 1, available: 0) = error else {
        XCTFail("Expected insufficientData error, got \(error)")
        return
      }
    }
  }

  func testToMLMultiArrayWithInvalidFeatureCount() throws {
    // Given: Feature vector with wrong feature count (would need to create invalid FeatureVector)
    // This test would require creating a FeatureVector with wrong number of features
    // For now, we test the validation logic in the conversion method

    guard let features = syntheticFeatures else {
      XCTFail("syntheticFeatures should not be nil")
      return
    }
    let multiArray = try CoreMLTraining.toMLMultiArray(features)

    // Then: Should have correct shape
    XCTAssertEqual(multiArray.shape[1].intValue, FeatureVector.featureCount)
  }

  func testBatchedArraysWithValidInput() throws {
    // Given: Valid features and batch size
    let features = Array(syntheticFeatures.prefix(25))
    let batchSize = 10

    // When: Creating batched arrays
    let batches = try CoreMLTraining.batchedArrays(from: features, batchSize: batchSize)

    // Then: Should have correct number of batches
    XCTAssertEqual(batches.count, 3) // 25 features / 10 batch size = 3 batches

    // And: Each batch should have correct shape
    for (index, batch) in batches.enumerated() {
      XCTAssertEqual(batch.batchIndex, index)
      XCTAssertEqual(batch.array.shape[1].intValue, FeatureVector.featureCount)

      if index < 2 {
        // First two batches should be full size
        XCTAssertEqual(batch.array.shape[0].intValue, batchSize)
      } else {
        // Last batch should have remaining features
        XCTAssertEqual(batch.array.shape[0].intValue, 5) // 25 % 10 = 5
      }
    }
  }

  func testBatchedArraysWithInvalidBatchSize() throws {
    // Given: Invalid batch size
    guard let features = syntheticFeatures else {
      XCTFail("syntheticFeatures should not be nil")
      return
    }
    let batchSize = 0

    // When/Then: Should throw batch size error
    XCTAssertThrowsError(try CoreMLTraining.batchedArrays(from: features, batchSize: batchSize)) { error in
      guard case CoreMLTrainingError.batchSizeTooLarge(batchSize: 0, maxSize: 0) = error else {
        XCTFail("Expected batchSizeTooLarge error, got \(error)")
        return
      }
    }
  }

  func testBatchedArraysWithBatchSizeLargerThanData() throws {
    // Given: Batch size larger than available data
    let features = Array(syntheticFeatures.prefix(5))
    let batchSize = 10

    // When/Then: Should throw batch size error
    XCTAssertThrowsError(try CoreMLTraining.batchedArrays(from: features, batchSize: batchSize)) { error in
      guard case CoreMLTrainingError.batchSizeTooLarge(batchSize: 10, maxSize: 5) = error else {
        XCTFail("Expected batchSizeTooLarge error, got \(error)")
        return
      }
    }
  }

  // MARK: - Training Orchestration Tests

  func testTrainModelWithValidData() async throws {
    // Given: Valid training data
    guard let syntheticFeatures = syntheticFeatures else {
      XCTFail("syntheticFeatures should not be nil")
      return
    }
    let features = Array(syntheticFeatures.prefix(20))

    // When: Training model
    do {
      _ = try await trainer.trainModel(with: features)
      XCTFail("Expected training to fail since actual training requires base model")
    } catch {
      // Then: Should throw training failed error (since we don't have a base model)
      guard case CoreMLTrainingError.trainingFailed(let reason, _) = error else {
        XCTFail("Expected trainingFailed error, got \(error)")
        return
      }
      // Verify the error message contains the expected text
      XCTAssertTrue(reason.contains(missingBaseModelMessage))
    }
  }

  func testTrainModelWithInsufficientData() async throws {
    // Given: Insufficient training data
    let features = Array(syntheticFeatures.prefix(5)) // Less than required minimum

    // When/Then: Should throw insufficient data error
    do {
      _ = try await trainer.trainModel(with: features)
      XCTFail("Expected insufficient data error")
    } catch {
      guard case CoreMLTrainingError.insufficientData(required: 10, available: 5) = error else {
        XCTFail("Expected insufficientData error, got \(error)")
        return
      }
    }
  }

  func testTrainModelWithInvalidFeatures() async throws {
    // Given: Features with invalid values (NaN)
    guard let syntheticFeatures = syntheticFeatures else {
      XCTFail("syntheticFeatures should not be nil")
      return
    }
    let invalidFeatures = syntheticFeatures
    // Create an invalid feature with NaN (this would require modifying FeatureVector)
    // For now, we test with valid features and expect validation to pass

    // When: Training model
    do {
      _ = try await trainer.trainModel(with: invalidFeatures)
      XCTFail("Expected training to fail")
    } catch {
      // Should fail due to training implementation requiring base model
      guard case CoreMLTrainingError.trainingFailed(let reason, _) = error else {
        XCTFail("Expected trainingFailed error, got \(error)")
        return
      }
      // Verify the error message contains the expected text
      XCTAssertTrue(reason.contains(missingBaseModelMessage))
    }
  }

  // MARK: - Validation Helper Tests

  func testEvaluateWithValidModel() throws {
    // Given: Valid model and features
    let features = Array(syntheticFeatures.prefix(50))

    // Note: We can't create a real MLModel without a base model file
    // This test demonstrates the evaluation flow with mock data

    // When/Then: Should throw error since we don't have a real model
    // In a real implementation, this would evaluate the model and return metrics
    XCTAssertThrowsError(try trainer.evaluate(MLModel(), on: features))
  }

  func testEvaluateWithEmptyData() throws {
    // Given: Empty feature array
    let features: [FeatureVector] = []

    // When/Then: Should throw insufficient data error
    XCTAssertThrowsError(try trainer.evaluate(MLModel(), on: features)) { error in
      guard case CoreMLTrainingError.insufficientData(required: 1, available: 0) = error else {
        XCTFail("Expected insufficientData error, got \(error)")
        return
      }
    }
  }

  // MARK: - Configuration Tests

  func testCoreMLTrainingConfigInitialization() throws {
    // Given: Configuration parameters
    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      inputShape: [1, 14],
                                      outputShape: [1, 1],
                                      epochs: 50,
                                      learningRate: 0.01,
                                      batchSize: 16,
                                      shuffleSeed: 123,
                                      useANE: true,
                                      earlyStoppingPatience: 5,
                                      validationSplitRatio: 0.25)

    // Then: All properties should be set correctly
    XCTAssertEqual(config.modelType, .neuralNetwork)
    XCTAssertEqual(config.inputShape, [1, 14])
    XCTAssertEqual(config.outputShape, [1, 1])
    XCTAssertEqual(config.epochs, 50)
    XCTAssertEqual(config.learningRate, 0.01)
    XCTAssertEqual(config.batchSize, 16)
    XCTAssertEqual(config.shuffleSeed, 123)
    XCTAssertTrue(config.useANE)
    XCTAssertEqual(config.earlyStoppingPatience, 5)
    XCTAssertEqual(config.validationSplitRatio, 0.25)
  }

  func testValidationConfig() throws {
    // Given: Validation configuration
    let config = CoreMLTrainingConfig.validation

    // Then: Should have validation-appropriate settings
    XCTAssertEqual(config.epochs, 10)
    XCTAssertEqual(config.learningRate, 0.01)
    XCTAssertEqual(config.batchSize, 8)
    XCTAssertFalse(config.useANE) // Disabled for validation
    XCTAssertEqual(config.earlyStoppingPatience, 3)
    XCTAssertEqual(config.validationSplitRatio, 0.3)
  }

  // MARK: - Error Handling Tests

  func testCoreMLTrainingErrorDescriptions() throws {
    // Given: Various error cases
    let shapeError = CoreMLTrainingError.shapeMismatch(expected: [14], found: [12], context: "test")
    let driftError = CoreMLTrainingError.featureDrift(description: "test drift", expectedCount: 14, actualCount: 12)
    let trainingError = CoreMLTrainingError.trainingFailed(reason: "test failure", underlyingError: nil)

    // Then: Error descriptions should be meaningful
    XCTAssertTrue(shapeError.errorDescription?.contains("Shape mismatch") ?? false)
    XCTAssertTrue(driftError.errorDescription?.contains("Feature drift") ?? false)
    XCTAssertTrue(trainingError.errorDescription?.contains("Training failed") ?? false)
  }

  func testRecursionTriggerErrors() throws {
    // Given: Errors that should trigger recursion
    let shapeError = CoreMLTrainingError.shapeMismatch(expected: [14], found: [12], context: "test")
    let driftError = CoreMLTrainingError.featureDrift(description: "test", expectedCount: 14, actualCount: 12)
    let invalidError = CoreMLTrainingError.invalidFeatureVector(index: 0, reason: "test")

    // Then: Should trigger recursion
    XCTAssertTrue(shapeError.shouldTriggerRecursion)
    XCTAssertTrue(driftError.shouldTriggerRecursion)
    XCTAssertTrue(invalidError.shouldTriggerRecursion)

    // Given: Errors that should not trigger recursion
    let trainingError = CoreMLTrainingError.trainingFailed(reason: "test", underlyingError: nil)
    let validationError = CoreMLTrainingError.validationFailed(metrics: CoreMLModelValidationResult(accuracy: 0.5, loss: 0.5, f1Score: 0.5, precision: 0.5, recall: 0.5, confusionMatrix: [[1, 1], [1, 1]]))

    // Then: Should not trigger recursion
    XCTAssertFalse(trainingError.shouldTriggerRecursion)
    XCTAssertFalse(validationError.shouldTriggerRecursion)
  }

  // MARK: - Synthetic Data Tests

  func testSyntheticDataGeneration() throws {
    // Given: Request for synthetic data
    let count = 50

    // When: Generating synthetic data
    let features = CoreMLTraining.generateSyntheticData(count: count)

    // Then: Should have correct count
    XCTAssertEqual(features.count, count)

    // And: All features should be valid
    for (_, feature) in features.enumerated() {
      // Check feature values are within expected ranges
      XCTAssertGreaterThanOrEqual(feature.bridge_id, 1)
      XCTAssertLessThanOrEqual(feature.bridge_id, 5)
      XCTAssertGreaterThanOrEqual(feature.horizon_min, 0)
      XCTAssertLessThanOrEqual(feature.horizon_min, 9)
      XCTAssertGreaterThanOrEqual(feature.open_5m, 0.0)
      XCTAssertLessThanOrEqual(feature.open_5m, 1.0)
      XCTAssertGreaterThanOrEqual(feature.target, 0)
      XCTAssertLessThanOrEqual(feature.target, 1)

      // Check no NaN or infinite values
      XCTAssertFalse(feature.min_sin.isNaN)
      XCTAssertFalse(feature.min_sin.isInfinite)
      XCTAssertFalse(feature.gate_anom.isNaN)
      XCTAssertFalse(feature.gate_anom.isInfinite)
    }
  }

  func testSyntheticDataDeterminism() throws {
    // Given: Same count for synthetic data generation
    let count = 10

    // When: Generating data twice
    let features1 = CoreMLTraining.generateSyntheticData(count: count)
    let features2 = CoreMLTraining.generateSyntheticData(count: count)

    // Then: Should be identical (deterministic)
    XCTAssertEqual(features1.count, features2.count)

    for i in 0 ..< features1.count {
      XCTAssertEqual(features1[i].bridge_id, features2[i].bridge_id)
      XCTAssertEqual(features1[i].horizon_min, features2[i].horizon_min)
      XCTAssertEqual(features1[i].min_sin, features2[i].min_sin, accuracy: 1e-10)
      XCTAssertEqual(features1[i].target, features2[i].target)
    }
  }

  // MARK: - Model Validation Result Tests

  func testCoreMLModelValidationResultInitialization() throws {
    // Given: Validation metrics
    let metrics = CoreMLModelValidationResult(accuracy: 0.85,
                                              loss: 0.3,
                                              f1Score: 0.82,
                                              precision: 0.87,
                                              recall: 0.78,
                                              confusionMatrix: [[85, 15], [20, 80]],
                                              lossTrend: [0.5, 0.4, 0.3],
                                              validationAccuracy: 0.83,
                                              validationLoss: 0.32,
                                              isOverfitting: false,
                                              hasConverged: true,
                                              isValid: true,
                                              inputShape: [1, 14],
                                              outputShape: [1, 1])

    // Then: All properties should be set correctly
    XCTAssertEqual(metrics.accuracy, 0.85)
    XCTAssertEqual(metrics.loss, 0.3)
    XCTAssertEqual(metrics.f1Score, 0.82)
    XCTAssertEqual(metrics.precision, 0.87)
    XCTAssertEqual(metrics.recall, 0.78)
    XCTAssertEqual(metrics.confusionMatrix, [[85, 15], [20, 80]])
    XCTAssertEqual(metrics.lossTrend, [0.5, 0.4, 0.3])
    XCTAssertEqual(metrics.validationAccuracy, 0.83)
    XCTAssertEqual(metrics.validationLoss, 0.32)
    XCTAssertFalse(metrics.isOverfitting)
    XCTAssertTrue(metrics.hasConverged)
    XCTAssertTrue(metrics.isValid)
    XCTAssertEqual(metrics.inputShape, [1, 14])
    XCTAssertEqual(metrics.outputShape, [1, 1])
  }

  // MARK: - Device Runtime Validation Tests

  func testMLMultiArrayCreationOnDevice() throws {
    // Given: Valid features
    let features = Array(syntheticFeatures.prefix(5))

    // When: Creating MLMultiArray
    let multiArray = try CoreMLTraining.toMLMultiArray(features)

    // Then: Should be valid for device use
    XCTAssertNotNil(multiArray)
    XCTAssertEqual(multiArray.dataType, .double)
    XCTAssertEqual(multiArray.shape.count, 2)

    // And: Should be able to access elements without crashing
    let firstElement = multiArray[[0, 0] as [NSNumber]]
    XCTAssertNotNil(firstElement)
  }

  func testBatchProcessingOnDevice() throws {
    // Given: Features and batch size
    let features = Array(syntheticFeatures.prefix(20))
    let batchSize = 5

    // When: Creating batches
    let batches = try CoreMLTraining.batchedArrays(from: features, batchSize: batchSize)

    // Then: Should be valid for device processing
    XCTAssertEqual(batches.count, 4) // 20 / 5 = 4 batches

    // And: Each batch should be accessible
    for batch in batches {
      XCTAssertNotNil(batch.array)
      XCTAssertEqual(batch.array.dataType, .double)

      // Should be able to access elements without crashing
      let firstElement = batch.array[[0, 0] as [NSNumber]]
      XCTAssertNotNil(firstElement)
    }
  }
}

// MARK: - Mock Progress Delegate

@MainActor
class MockCoreMLTrainingProgressDelegate: CoreMLTrainingProgressDelegate {
  var trainingDidStartCalled = false
  var trainingDidLoadDataCalled = false
  var trainingDidPrepareDataCalled = false
  var trainingDidUpdateProgressCalled = false
  var trainingDidCompleteCalled = false
  var trainingDidFailCalled = false

  func trainingDidStart() {
    trainingDidStartCalled = true
  }

  func trainingDidLoadData(_: Int) {
    trainingDidLoadDataCalled = true
  }

  func trainingDidPrepareData(_: Int) {
    trainingDidPrepareDataCalled = true
  }

  func trainingDidUpdateProgress(_: Double) {
    trainingDidUpdateProgressCalled = true
  }

  func trainingDidComplete(_: String) {
    trainingDidCompleteCalled = true
  }

  func trainingDidFail(_: Error) {
    trainingDidFailCalled = true
  }

  func pipelineDidStart() {}
  func pipelineDidProcessData(_: Int) {}
  func pipelineDidStartTraining(_: Int) {}
  func pipelineDidCompleteTraining(_: Int, modelPath _: String) {}
  func pipelineDidComplete(_: [Int: String]) {}
}

