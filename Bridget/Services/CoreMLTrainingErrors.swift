// CoreMLTrainingErrors.swift
import Foundation

public enum CoreMLTrainingError: Error, LocalizedError {
  case shapeMismatch(expected: [Int], found: [Int], context: String)
  case featureDrift(description: String, expectedCount: Int, actualCount: Int)
  case invalidFeatureVector(index: Int, reason: String)
  case trainingFailed(reason: String, underlyingError: Error?)
  case validationFailed(metrics: CoreMLModelValidationResult)
  case modelCreationFailed(reason: String)
  case insufficientData(required: Int, available: Int)
  case batchSizeTooLarge(batchSize: Int, maxSize: Int)

  public var errorDescription: String? {
    switch self {
    case let .shapeMismatch(expected, found, context):
      return
        "Shape mismatch in \(context): expected \(expected), found \(found)"
    case let .featureDrift(description, expected, actual):
      return
        "Feature drift: \(description) (expected \(expected), actual \(actual))"
    case let .invalidFeatureVector(index, reason):
      return "Invalid feature vector at index \(index): \(reason)"
    case let .trainingFailed(reason, underlyingError):
      if let underlying = underlyingError {
        return
          "Training failed: \(reason) - \(underlying.localizedDescription)"
      }
      return "Training failed: \(reason)"
    case let .validationFailed(metrics):
      return
        "Validation failed: accuracy \(metrics.accuracy), loss \(metrics.loss)"
    case let .modelCreationFailed(reason):
      return "Model creation failed: \(reason)"
    case let .insufficientData(required, available):
      return
        "Insufficient data: required \(required), available \(available)"
    case let .batchSizeTooLarge(batchSize, maxSize):
      return "Batch size too large: \(batchSize) > \(maxSize)"
    }
  }

  public var shouldTriggerRecursion: Bool {
    switch self {
    case .shapeMismatch, .featureDrift, .invalidFeatureVector:
      return true
    case .trainingFailed, .validationFailed, .modelCreationFailed,
         .insufficientData, .batchSizeTooLarge:
      return false
    }
  }
}
