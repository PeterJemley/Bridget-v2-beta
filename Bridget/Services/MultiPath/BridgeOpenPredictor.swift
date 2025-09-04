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
public struct BridgePredictionInput: Codable, Hashable, Sendable {
  public let bridgeID: String
  public let eta: Date
  public let features: [Double]

  public init(bridgeID: String, eta: Date, features: [Double]) {
    self.bridgeID = bridgeID
    self.eta = eta
    self.features = features
  }
}

/// Prediction result for a single bridge
public struct BridgePredictionResult: Codable, Sendable {
  public let bridgeID: String
  public let eta: Date
  public let openProbability: Double
  public let confidence: Double?

  public init(bridgeID: String,
              eta: Date,
              openProbability: Double,
              confidence: Double? = nil)
  {
    self.bridgeID = bridgeID
    self.eta = eta
    self.openProbability = max(0.0, min(1.0, openProbability))
    self.confidence = confidence
  }
}

/// Batch prediction result
public struct BatchPredictionResult: Codable, Sendable {
  public let predictions: [BridgePredictionResult]
  public let processingTime: TimeInterval
  public let batchSize: Int

  public init(predictions: [BridgePredictionResult],
              processingTime: TimeInterval,
              batchSize: Int)
  {
    self.predictions = predictions
    self.processingTime = processingTime
    self.batchSize = batchSize
  }
}

/// Protocol for bridge opening prediction
public protocol BridgeOpenPredictor {
  func predict(bridgeID: String, eta: Date, features: [Double]) async throws
    -> BridgePredictionResult

  func predictBatch(_ inputs: [BridgePredictionInput]) async throws
    -> BatchPredictionResult

  var defaultProbability: Double { get }

  func supports(bridgeID: String) -> Bool

  var maxBatchSize: Int { get }
}

// MARK: - Prediction Errors

public enum BridgePredictionError: Error, LocalizedError, Sendable {
  case unsupportedBridge(String)
  case invalidFeatures(String)
  case predictionFailed(String)
  case batchSizeExceeded(Int, Int)
  case modelNotLoaded(String)

  public var errorDescription: String? {
    switch self {
    case let .unsupportedBridge(bridgeID):
      return "Bridge not supported: \(bridgeID)"
    case let .invalidFeatures(reason):
      return "Invalid features: \(reason)"
    case let .predictionFailed(reason):
      return "Prediction failed: \(reason)"
    case let .batchSizeExceeded(requested, max):
      return "Batch size \(requested) exceeds maximum \(max)"
    case let .modelNotLoaded(reason):
      return "Model not loaded: \(reason)"
    }
  }
}

// MARK: - Default Implementation

public extension BridgeOpenPredictor {
  func predict(bridgeID: String, eta: Date, features: [Double])
    async throws
    -> BridgePredictionResult
  {
    let input = BridgePredictionInput(bridgeID: bridgeID,
                                      eta: eta,
                                      features: features)
    let batchResult = try await predictBatch([input])

    guard let result = batchResult.predictions.first else {
      throw BridgePredictionError.predictionFailed(
        "No prediction returned from batch"
      )
    }

    return result
  }

  func predictBatch(_ inputs: [BridgePredictionInput]) async throws
    -> BatchPredictionResult
  {
    let startTime = Date()
    var predictions: [BridgePredictionResult] = []

    for input in inputs {
      let result = try await predict(bridgeID: input.bridgeID,
                                     eta: input.eta,
                                     features: input.features)
      predictions.append(result)
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return BatchPredictionResult(predictions: predictions,
                                 processingTime: processingTime,
                                 batchSize: inputs.count)
  }

  func supports(bridgeID _: String) -> Bool {
    return true
  }

  var maxBatchSize: Int {
    return 100
  }
}

// MARK: - Prediction Utilities

public enum BridgePredictionUtils {
  public static func validateInput(_ input: BridgePredictionInput) throws {
    if input.bridgeID.isEmpty {
      throw BridgePredictionError.invalidFeatures(
        "Bridge ID cannot be empty"
      )
    }

    if input.features.isEmpty {
      throw BridgePredictionError.invalidFeatures(
        "Features cannot be empty"
      )
    }

    for (index, feature) in input.features.enumerated() {
      if feature.isNaN {
        throw BridgePredictionError.invalidFeatures(
          "Feature \(index) is NaN"
        )
      }
      if feature.isInfinite {
        throw BridgePredictionError.invalidFeatures(
          "Feature \(index) is infinite"
        )
      }
    }
  }

  public static func validateBatch(_ inputs: [BridgePredictionInput],
                                   maxBatchSize: Int) throws
  {
    if inputs.isEmpty {
      throw BridgePredictionError.invalidFeatures("Batch cannot be empty")
    }

    if inputs.count > maxBatchSize {
      throw BridgePredictionError.batchSizeExceeded(inputs.count,
                                                    maxBatchSize)
    }

    for input in inputs {
      try validateInput(input)
    }
  }

  public static func clampProbability(_ probability: Double) -> Double {
    return max(0.0, min(1.0, probability))
  }

  public static func toLogProbability(_ probability: Double) -> Double {
    let clamped = clampProbability(probability)
    return clamped > 0 ? log(clamped) : -Double.infinity
  }

  public static func fromLogProbability(_ logProbability: Double) -> Double {
    return exp(logProbability)
  }
}
