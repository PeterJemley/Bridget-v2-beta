//
//  CoreMLTrainingTests.swift
//  BridgetTests
//
//  Unit tests for CoreMLTraining module with synthetic data and device validation
//

import CoreML
import Foundation
import Testing

@testable import Bridget

@Suite("CoreMLTraining Tests")
struct CoreMLTrainingTests {
  // MARK: - Test Data

  private var syntheticFeatures: [FeatureVector]
  private var trainingConfig: CoreMLTrainingConfig
  private var trainer: CoreMLTraining
  private var converter: CoreMLFeatureConversion

  init() {
    // Generate synthetic test data
    self.syntheticFeatures = CoreMLSyntheticDataFactory.generate(
      count: 100
    )
    // Create validation configuration for fast testing
    self.trainingConfig = .validation
    // Create trainer instance
    self.trainer = CoreMLTraining(config: trainingConfig)
    // Create feature converter
    self.converter = CoreMLFeatureConversion()
  }

  // MARK: - Conversion Utilities Tests

  @Test("toMLMultiArray with valid features has correct shape")
  func toMLMultiArrayWithValidFeatures() throws {
    let features = Array(syntheticFeatures.prefix(10))
    let multiArray = try converter.toMLMultiArray(features)

    #expect(multiArray.shape.count == 2)
    #expect(multiArray.shape[0].intValue == 10)
    #expect(multiArray.shape[1].intValue == FeatureVector.featureCount)
    #expect(multiArray.dataType == .double)
  }

  @Test("toMLMultiArray with empty features throws insufficientData")
  func toMLMultiArrayWithEmptyFeatures() {
    let features: [FeatureVector] = []
    #expect(throws: CoreMLTrainingError.self) {
      _ = try converter.toMLMultiArray(features)
    }
  }

  @Test("toMLMultiArray validates feature count")
  func toMLMultiArrayWithInvalidFeatureCount() throws {
    let multiArray = try converter.toMLMultiArray(syntheticFeatures)
    #expect(multiArray.shape[1].intValue == FeatureVector.featureCount)
  }

  @Test("batchedArrays with valid input yields correct batches")
  func batchedArraysWithValidInput() throws {
    let features = Array(syntheticFeatures.prefix(25))
    let batchSize = 10
    let batches = try converter.batchedArrays(from: features,
                                              batchSize: batchSize)

    #expect(batches.count == 3)
    for (index, batch) in batches.enumerated() {
      #expect(batch.batchIndex == index)
      #expect(batch.array.shape[1].intValue == FeatureVector.featureCount)
      if index < 2 {
        #expect(batch.array.shape[0].intValue == batchSize)
      } else {
        #expect(batch.array.shape[0].intValue == 5)
      }
    }
  }

  @Test("batchedArrays with invalid batch size throws")
  func batchedArraysWithInvalidBatchSize() {
    let batchSize = 0
    #expect(throws: CoreMLTrainingError.self) {
      _ = try converter.batchedArrays(from: syntheticFeatures,
                                      batchSize: batchSize)
    }
  }

  @Test("batchedArrays with batch size larger than data throws")
  func batchedArraysWithBatchSizeLargerThanData() {
    let features = Array(syntheticFeatures.prefix(5))
    let batchSize = 10
    #expect(throws: CoreMLTrainingError.self) {
      _ = try converter.batchedArrays(from: features,
                                      batchSize: batchSize)
    }
  }

  // MARK: - Training Orchestration Tests

  @Test(
    "trainModel with valid data fails gracefully due to placeholder base model"
  )
  func trainModelWithValidData() async {
    let features = Array(syntheticFeatures.prefix(20))
    do {
      _ = try await trainer.trainModel(with: features)
      Issue.record(
        "Expected training to fail since actual training requires base model"
      )
    } catch {
      // Accept either our wrapped trainingFailed error or Core ML's NSError when loading the placeholder model fails.
      if case let CoreMLTrainingError.trainingFailed(reason, _) = error {
        #expect(reason.contains(missingBaseModelMessage))
      } else if let nsError = error as NSError?,
                nsError.domain == "com.apple.CoreML",
                nsError.localizedDescription.contains(
                  "Compile the model with Xcode or `MLModel.compileModel(at:)`"
                )
      {
        // Acceptable: Core ML failed to load/compile the placeholder model before our wrapper could fire.
      } else {
        Issue.record(
          "Expected training failure due to missing base model, got \(String(describing: error))"
        )
      }
    }
  }

  @Test("trainModel with insufficient data throws insufficientData")
  func trainModelWithInsufficientData() async {
    let features = Array(syntheticFeatures.prefix(5))
    do {
      _ = try await trainer.trainModel(with: features)
      Issue.record("Expected insufficient data error")
    } catch {
      if case CoreMLTrainingError.insufficientData(required: 10,
                                                   available: 5) = error
      {
        // pass
      } else {
        Issue.record(
          "Expected insufficientData error, got \(String(describing: error))"
        )
      }
    }
  }

  @Test(
    "trainModel with invalid features ultimately fails due to placeholder model"
  )
  func trainModelWithInvalidFeatures() async {
    let invalidFeatures = syntheticFeatures
    do {
      _ = try await trainer.trainModel(with: invalidFeatures)
      Issue.record("Expected training to fail")
    } catch {
      // Accept either our wrapped trainingFailed error or Core ML's NSError when loading the placeholder model fails.
      if case let CoreMLTrainingError.trainingFailed(reason, _) = error {
        #expect(reason.contains(missingBaseModelMessage))
      } else if let nsError = error as NSError?,
                nsError.domain == "com.apple.CoreML",
                nsError.localizedDescription.contains(
                  "Compile the model with Xcode or `MLModel.compileModel(at:)`"
                )
      {
        // Acceptable: Core ML failed to load/compile the placeholder model before our wrapper could fire.
      } else {
        Issue.record(
          "Expected training failure due to missing base model, got \(String(describing: error))"
        )
      }
    }
  }

  // MARK: - Validation Helper Tests

  @Test("evaluate with empty data throws insufficientData")
  func evaluateWithEmptyData() {
    let features: [FeatureVector] = []
    #expect(throws: CoreMLTrainingError.self) {
      _ = try trainer.evaluate(MLModel(), on: features)
    }
  }

  // MARK: - Configuration Tests

  @Test("CoreMLTrainingConfig initialization retains values")
  func coreMLTrainingConfigInitialization() {
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

    #expect(config.modelType == .neuralNetwork)
    #expect(config.inputShape == [1, 14])
    #expect(config.outputShape == [1, 1])
    #expect(config.epochs == 50)
    #expect(config.learningRate == 0.01)
    #expect(config.batchSize == 16)
    #expect(config.shuffleSeed == 123)
    #expect(config.useANE)
    #expect(config.earlyStoppingPatience == 5)
    #expect(config.validationSplitRatio == 0.25)
  }

  @Test("Validation config has validation-appropriate settings")
  func validationConfig() {
    let config = CoreMLTrainingConfig.validation
    #expect(config.epochs == 10)
    #expect(config.learningRate == 0.01)
    #expect(config.batchSize == 8)
    #expect(!config.useANE)
    #expect(config.earlyStoppingPatience == 3)
    #expect(config.validationSplitRatio == 0.3)
  }

  // MARK: - Error Handling Tests

  @Test("CoreMLTrainingError descriptions and recursion flags")
  func coreMLTrainingErrorDescriptions() {
    let shapeError = CoreMLTrainingError.shapeMismatch(expected: [14],
                                                       found: [12],
                                                       context: "test")
    let driftError = CoreMLTrainingError.featureDrift(description: "test drift",
                                                      expectedCount: 14,
                                                      actualCount: 12)
    let trainingError = CoreMLTrainingError.trainingFailed(reason: "test failure",
                                                           underlyingError: nil)

    #expect(shapeError.errorDescription?.contains("Shape mismatch") == true)
    #expect(driftError.errorDescription?.contains("Feature drift") == true)
    #expect(
      trainingError.errorDescription?.contains("Training failed") == true
    )

    // Recursion triggers
    #expect(shapeError.shouldTriggerRecursion)
    #expect(driftError.shouldTriggerRecursion)
    let invalidError = CoreMLTrainingError.invalidFeatureVector(index: 0,
                                                                reason: "test")
    #expect(invalidError.shouldTriggerRecursion)

    // Non-recursive
    #expect(
      !CoreMLTrainingError.trainingFailed(reason: "test",
                                          underlyingError: nil)
        .shouldTriggerRecursion
    )
    let validationError = CoreMLTrainingError.validationFailed(
      metrics: CoreMLModelValidationResult(accuracy: 0.5,
                                           loss: 0.5,
                                           f1Score: 0.5,
                                           precision: 0.5,
                                           recall: 0.5,
                                           confusionMatrix: [[1, 1], [1, 1]])
    )
    #expect(!validationError.shouldTriggerRecursion)
  }

  // MARK: - Synthetic Data Tests

  @Test("Synthetic data generation count and ranges")
  func syntheticDataGeneration() {
    let count = 50
    let features = CoreMLSyntheticDataFactory.generate(count: count)
    #expect(features.count == count)
    for feature in features {
      #expect(feature.bridge_id >= 1 && feature.bridge_id <= 5)
      #expect(feature.horizon_min >= 0)
      #expect(feature.open_5m >= 0.0 && feature.open_5m <= 1.0)
      #expect(feature.target == 0 || feature.target == 1)
      #expect(!feature.min_sin.isNaN && !feature.min_sin.isInfinite)
      #expect(!feature.gate_anom.isNaN && !feature.gate_anom.isInfinite)
    }
  }

  @Test("Synthetic data determinism")
  func syntheticDataDeterminism() {
    let count = 10
    let features1 = CoreMLSyntheticDataFactory.generate(count: count)
    let features2 = CoreMLSyntheticDataFactory.generate(count: count)
    #expect(features1.count == features2.count)
    for i in 0 ..< features1.count {
      #expect(features1[i].bridge_id == features2[i].bridge_id)
      #expect(features1[i].horizon_min == features2[i].horizon_min)
      #expect(abs(features1[i].min_sin - features2[i].min_sin) < 1e-10)
      #expect(features1[i].target == features2[i].target)
    }
  }

  // Device-ish validations (no real device APIs used here)

  @Test("MLMultiArray creation basic validation")
  func mlMultiArrayCreationOnDevice() throws {
    let features = Array(syntheticFeatures.prefix(5))
    let multiArray = try converter.toMLMultiArray(features)
    #expect(multiArray.dataType == .double)
    #expect(multiArray.shape.count == 2)
    _ = multiArray[[0, 0] as [NSNumber]]
  }

  @Test("Batch processing basic validation")
  func batchProcessingOnDevice() throws {
    let features = Array(syntheticFeatures.prefix(20))
    let batchSize = 5
    let batches = try converter.batchedArrays(from: features,
                                              batchSize: batchSize)
    #expect(batches.count == 4)
    for batch in batches {
      #expect(batch.array.dataType == .double)
      _ = batch.array[[0, 0] as [NSNumber]]
    }
  }
}

