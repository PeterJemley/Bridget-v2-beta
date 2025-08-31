//
//  BridgeOpenPredictor.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Protocol for bridge opening prediction with batch support
//  Integration: Used by PathScoringService for probability computation
//  Acceptance: Batch prediction, async support, clear error handling
//  Known Limits: Predictions are probabilities [0,1], batch size configurable
//

import Foundation

/// Input features for bridge opening prediction
public struct BridgePredictionInput: Codable, Hashable {
  public let bridgeID: String
  public let eta: Date
  public let features: [Double]  // ML model features

  public init(bridgeID: String, eta: Date, features: [Double]) {
    self.bridgeID = bridgeID
    self.eta = eta
    self.features = features
  }
}

/// Prediction result for a single bridge
public struct BridgePredictionResult: Codable {
  public let bridgeID: String
  public let eta: Date
  public let openProbability: Double  // probability bridge will be open
  public let confidence: Double?  // optional confidence score

  public init(bridgeID: String, eta: Date, openProbability: Double, confidence: Double? = nil) {
    self.bridgeID = bridgeID
    self.eta = eta
    self.openProbability = max(0.0, min(1.0, openProbability))  // clamp to [0,1]
    self.confidence = confidence
  }
}

/// Batch prediction result
public struct BatchPredictionResult: Codable {
  public let predictions: [BridgePredictionResult]
  public let processingTime: TimeInterval
  public let batchSize: Int

  public init(predictions: [BridgePredictionResult], processingTime: TimeInterval, batchSize: Int) {
    self.predictions = predictions
    self.processingTime = processingTime
    self.batchSize = batchSize
  }
}

/// Protocol for bridge opening prediction
/// Supports both single and batch predictions for performance
public protocol BridgeOpenPredictor {
  /// Predict opening probability for a single bridge
  func predict(bridgeID: String, eta: Date, features: [Double]) async throws
    -> BridgePredictionResult

  /// Predict opening probabilities for multiple bridges (batch)
  /// More efficient than multiple single predictions
  func predictBatch(_ inputs: [BridgePredictionInput]) async throws -> BatchPredictionResult

  /// Get the default probability for bridges not supported by this predictor
  var defaultProbability: Double { get }

  /// Check if this predictor supports a specific bridge
  func supports(bridgeID: String) -> Bool

  /// Get the maximum batch size supported by this predictor
  var maxBatchSize: Int { get }
}

// MARK: - Prediction Errors

/// Errors specific to bridge prediction
public enum BridgePredictionError: Error, LocalizedError {
  case unsupportedBridge(String)
  case invalidFeatures(String)
  case predictionFailed(String)
  case batchSizeExceeded(Int, Int)  // requested, max
  case modelNotLoaded(String)

  public var errorDescription: String? {
    switch self {
    case .unsupportedBridge(let bridgeID):
      return "Bridge not supported: \(bridgeID)"
    case .invalidFeatures(let reason):
      return "Invalid features: \(reason)"
    case .predictionFailed(let reason):
      return "Prediction failed: \(reason)"
    case .batchSizeExceeded(let requested, let max):
      return "Batch size \(requested) exceeds maximum \(max)"
    case .modelNotLoaded(let reason):
      return "Model not loaded: \(reason)"
    }
  }
}

// MARK: - Default Implementation

extension BridgeOpenPredictor {
  /// Default implementation of single prediction using batch
  public func predict(bridgeID: String, eta: Date, features: [Double]) async throws
    -> BridgePredictionResult
  {
    let input = BridgePredictionInput(bridgeID: bridgeID, eta: eta, features: features)
    let batchResult = try await predictBatch([input])

    guard let result = batchResult.predictions.first else {
      throw BridgePredictionError.predictionFailed("No prediction returned from batch")
    }

    return result
  }

  /// Default implementation of batch prediction using single predictions
  public func predictBatch(_ inputs: [BridgePredictionInput]) async throws -> BatchPredictionResult
  {
    let startTime = Date()
    var predictions: [BridgePredictionResult] = []

    for input in inputs {
      let result = try await predict(
        bridgeID: input.bridgeID, eta: input.eta, features: input.features)
      predictions.append(result)
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return BatchPredictionResult(
      predictions: predictions,
      processingTime: processingTime,
      batchSize: inputs.count)
  }

  /// Default implementation of supports check
  public func supports(bridgeID _: String) -> Bool {
    return true  // Override in specific implementations
  }

  /// Default maximum batch size
  public var maxBatchSize: Int {
    return 100
  }
}

// MARK: - Prediction Utilities

/// Utility functions for bridge prediction
public enum BridgePredictionUtils {
  /// Validate prediction inputs
  public static func validateInput(_ input: BridgePredictionInput) throws {
    if input.bridgeID.isEmpty {
      throw BridgePredictionError.invalidFeatures("Bridge ID cannot be empty")
    }

    if input.features.isEmpty {
      throw BridgePredictionError.invalidFeatures("Features cannot be empty")
    }

    // Check for NaN or infinite values
    for (index, feature) in input.features.enumerated() {
      if feature.isNaN {
        throw BridgePredictionError.invalidFeatures("Feature \(index) is NaN")
      }
      if feature.isInfinite {
        throw BridgePredictionError.invalidFeatures("Feature \(index) is infinite")
      }
    }
  }

  /// Validate batch inputs
  public static func validateBatch(_ inputs: [BridgePredictionInput], maxBatchSize: Int) throws {
    if inputs.isEmpty {
      throw BridgePredictionError.invalidFeatures("Batch cannot be empty")
    }

    if inputs.count > maxBatchSize {
      throw BridgePredictionError.batchSizeExceeded(inputs.count, maxBatchSize)
    }

    for input in inputs {
      try validateInput(input)
    }
  }

  /// Clamp probability to valid range
  public static func clampProbability(_ probability: Double) -> Double {
    return max(0.0, min(1.0, probability))
  }

  /// Convert probability to log domain for numerical stability
  public static func toLogProbability(_ probability: Double) -> Double {
    let clamped = clampProbability(probability)
    return clamped > 0 ? log(clamped) : -Double.infinity
  }

  /// Convert log probability back to linear domain
  public static func fromLogProbability(_ logProbability: Double) -> Double {
    return exp(logProbability)
  }
}
