//
//  MockBridgePredictor.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Deterministic mock predictor for testing and development
//  Integration: Implements BridgeOpenPredictor protocol for testability
//  Acceptance: Seeded PRNG, batch implementation, reproducible outputs
//  Known Limits: Deterministic only, no real ML inference, configurable default probability
//

import Foundation

/// Mock bridge opening predictor for testing and development
/// Uses seeded PRNG for deterministic, reproducible predictions
public class MockBridgePredictor: BridgeOpenPredictor {
  private let seed: UInt64
  public let defaultProbability: Double
  private let supportedBridges: Set<String>
  private var randomGenerator: SeededRandomGenerator

  public init(seed: UInt64 = 42,
              defaultProbability: Double = 0.8,
              supportedBridges: Set<String> = [])
  {
    self.seed = seed
    self.defaultProbability = defaultProbability

    // Validate that all provided bridge IDs are canonical Seattle bridges
    if !supportedBridges.isEmpty {
      let canonicalIDs = Set(SeattleDrawbridges.BridgeID.allIDs)
      let nonCanonicalIDs = supportedBridges.subtracting(canonicalIDs)

      if !nonCanonicalIDs.isEmpty {
        print(
          "⚠️ MockBridgePredictor: Non-canonical bridge IDs detected: \(nonCanonicalIDs). Using canonical Seattle bridges only."
        )
      }

      // Only use IDs that are canonical Seattle bridges
      self.supportedBridges = supportedBridges.intersection(canonicalIDs)
    } else {
      // Default to all canonical Seattle bridges
      self.supportedBridges = Set(SeattleDrawbridges.BridgeID.allIDs)
    }

    self.randomGenerator = SeededRandomGenerator(seed: seed)
  }

  /// Create MockBridgePredictor from MultiPathConfig
  /// - Parameter config: MultiPathConfig containing predictor settings
  /// - Returns: Configured MockBridgePredictor instance
  public convenience init(config: MultiPathConfig) {
    self.init(seed: config.pathEnumeration.randomSeed,
              defaultProbability: config.prediction.defaultBridgeProbability,
              supportedBridges: [])
  }

  // MARK: - BridgeOpenPredictor Implementation

  public func predict(bridgeID: String, eta: Date, features: [Double]) async throws
    -> BridgePredictionResult
  {
    try BridgePredictionUtils.validateInput(
      BridgePredictionInput(bridgeID: bridgeID, eta: eta, features: features))

    let probability = generateProbability(for: bridgeID, eta: eta, features: features)
    let confidence = generateConfidence(for: bridgeID)

    return BridgePredictionResult(bridgeID: bridgeID,
                                  eta: eta,
                                  openProbability: probability,
                                  confidence: confidence)
  }

  public func predictBatch(_ inputs: [BridgePredictionInput]) async throws -> BatchPredictionResult {
    try BridgePredictionUtils.validateBatch(inputs, maxBatchSize: maxBatchSize)

    let startTime = Date()
    var predictions: [BridgePredictionResult] = []

    for input in inputs {
      let probability = generateProbability(for: input.bridgeID, eta: input.eta, features: input.features)
      let confidence = generateConfidence(for: input.bridgeID)

      let result = BridgePredictionResult(bridgeID: input.bridgeID,
                                          eta: input.eta,
                                          openProbability: probability,
                                          confidence: confidence)
      predictions.append(result)
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return BatchPredictionResult(predictions: predictions,
                                 processingTime: processingTime,
                                 batchSize: inputs.count)
  }

  public var maxBatchSize: Int {
    return 1000  // High limit for mock predictor
  }

  public func supports(bridgeID: String) -> Bool {
    // First check if it's in our supported bridges set
    let isSupported = supportedBridges.isEmpty || supportedBridges.contains(bridgeID)

    // Then validate against SeattleDrawbridges as the single source of truth
    // Allow both canonical Seattle bridges and synthetic test IDs
    let isAccepted = SeattleDrawbridges.isAcceptedBridgeID(bridgeID, allowSynthetic: true)

    // Support bridges that are both in our set AND accepted by policy
    return isSupported && isAccepted
  }

  // MARK: - Private Methods

  /// Generate a deterministic probability for a bridge
  private func generateProbability(for bridgeID: String, eta: Date, features: [Double]) -> Double {
    // Use bridgeID, time components, and features to generate deterministic probability
    var hash = bridgeID.hashValue
    hash = hash &+ eta.timeIntervalSince1970.hashValue

    for feature in features {
      hash = hash &+ feature.hashValue
    }

    // Use the hash to seed a temporary generator for this prediction
    let tempGenerator = SeededRandomGenerator(seed: UInt64(bitPattern: Int64(hash)))

    // Generate probability based on time of day and bridge characteristics
    let hour = Calendar.current.component(.hour, from: eta)
    let _ = Calendar.current.component(.minute, from: eta)

    // Base probability varies by time of day
    var baseProbability: Double

    switch hour {
    case 6 ..< 9:  // Morning rush
      baseProbability = 0.6
    case 9 ..< 16:  // Midday
      baseProbability = 0.8
    case 16 ..< 19:  // Evening rush
      baseProbability = 0.7
    case 19 ..< 22:  // Evening
      baseProbability = 0.9
    default:  // Late night
      baseProbability = 0.95
    }

    // Add some randomness based on bridge ID and features
    let randomFactor = tempGenerator.nextDouble() * 0.3 - 0.15  // ±15%
    let featureFactor =
      features.isEmpty ? 0.0 : features.reduce(0, +) / Double(features.count) * 0.1

    let finalProbability = baseProbability + randomFactor + featureFactor

    return BridgePredictionUtils.clampProbability(finalProbability)
  }

  /// Generate a deterministic confidence score
  private func generateConfidence(for bridgeID: String) -> Double {
    // Use bridgeID to generate consistent confidence
    let hash = bridgeID.hashValue
    let tempGenerator = SeededRandomGenerator(seed: UInt64(bitPattern: Int64(hash)))

    // Confidence between 0.7 and 1.0
    return 0.7 + tempGenerator.nextDouble() * 0.3
  }

  /// Reset the random generator to initial state
  public func reset() {
    randomGenerator = SeededRandomGenerator(seed: seed)
  }

  /// Get the current seed
  public var currentSeed: UInt64 {
    return seed
  }
}

// MARK: - Seeded Random Generator

/// Deterministic random number generator for reproducible testing
private class SeededRandomGenerator {
  private var state: UInt64

  init(seed: UInt64) {
    self.state = seed
  }

  /// Generate next random double in [0, 1)
  func nextDouble() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1
    let value = Double(state >> 16) / Double(UInt64.max >> 16)
    return value
  }

  /// Generate next random integer in [0, max)
  func nextInt(max: UInt64) -> UInt64 {
    return UInt64(nextDouble() * Double(max))
  }

  /// Generate next random boolean
  func nextBool() -> Bool {
    return nextDouble() < 0.5
  }
}

// MARK: - Mock Predictor Factory

public extension MockBridgePredictor {
  /// Create a mock predictor for testing with specific bridge support
  static func createForTesting(seed: UInt64 = 42,
                               supportedBridges: Set<String> = ["bridge1", "bridge2", "bridge3"]) -> MockBridgePredictor
  {
    return MockBridgePredictor(seed: seed,
                               defaultProbability: 0.8,
                               supportedBridges: supportedBridges)
  }

  /// Create a mock predictor that always returns the same probability
  static func createConstant(probability: Double = 0.8,
                             supportedBridges: Set<String> = []) -> BridgeOpenPredictor
  {
    return ConstantMockPredictor(probability: probability,
                                 supportedBridges: supportedBridges)
  }

  /// Create a mock predictor that alternates between high and low probabilities
  static func createAlternating(highProbability: Double = 0.9,
                                lowProbability: Double = 0.1,
                                supportedBridges: Set<String> = []) -> BridgeOpenPredictor
  {
    return AlternatingMockPredictor(highProbability: highProbability,
                                    lowProbability: lowProbability,
                                    supportedBridges: supportedBridges)
  }
}

// MARK: - Specialized Mock Predictors

/// Mock predictor that always returns the same probability
private class ConstantMockPredictor: BridgeOpenPredictor {
  private let probability: Double
  private let supportedBridges: Set<String>

  init(probability: Double, supportedBridges: Set<String>) {
    self.probability = BridgePredictionUtils.clampProbability(probability)
    self.supportedBridges = supportedBridges
  }

  func predict(bridgeID: String, eta: Date, features _: [Double]) async throws
    -> BridgePredictionResult
  {
    return BridgePredictionResult(bridgeID: bridgeID,
                                  eta: eta,
                                  openProbability: probability,
                                  confidence: 1.0)
  }

  func predictBatch(_ inputs: [BridgePredictionInput]) async throws -> BatchPredictionResult {
    let startTime = Date()
    let predictions = inputs.map { input in
      BridgePredictionResult(bridgeID: input.bridgeID,
                             eta: input.eta,
                             openProbability: probability,
                             confidence: 1.0)
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return BatchPredictionResult(predictions: predictions,
                                 processingTime: processingTime,
                                 batchSize: inputs.count)
  }

  var defaultProbability: Double { probability }
  var maxBatchSize: Int { 1000 }

  func supports(bridgeID: String) -> Bool {
    return supportedBridges.isEmpty || supportedBridges.contains(bridgeID)
  }
}

/// Mock predictor that alternates between high and low probabilities
private class AlternatingMockPredictor: BridgeOpenPredictor {
  private let highProbability: Double
  private let lowProbability: Double
  private let supportedBridges: Set<String>
  private var counter = 0

  init(highProbability: Double, lowProbability: Double, supportedBridges: Set<String>) {
    self.highProbability = BridgePredictionUtils.clampProbability(highProbability)
    self.lowProbability = BridgePredictionUtils.clampProbability(lowProbability)
    self.supportedBridges = supportedBridges
  }

  func predict(bridgeID: String, eta: Date, features _: [Double]) async throws
    -> BridgePredictionResult
  {
    let probability = counter % 2 == 0 ? highProbability : lowProbability
    counter += 1

    return BridgePredictionResult(bridgeID: bridgeID,
                                  eta: eta,
                                  openProbability: probability,
                                  confidence: 0.8)
  }

  func predictBatch(_ inputs: [BridgePredictionInput]) async throws -> BatchPredictionResult {
    let startTime = Date()
    var predictions: [BridgePredictionResult] = []

    for input in inputs {
      let probability = counter % 2 == 0 ? highProbability : lowProbability
      counter += 1

      let result = BridgePredictionResult(bridgeID: input.bridgeID,
                                          eta: input.eta,
                                          openProbability: probability,
                                          confidence: 0.8)
      predictions.append(result)
    }

    let processingTime = Date().timeIntervalSince(startTime)
    return BatchPredictionResult(predictions: predictions,
                                 processingTime: processingTime,
                                 batchSize: inputs.count)
  }

  var defaultProbability: Double { (highProbability + lowProbability) / 2 }
  var maxBatchSize: Int { 1000 }

  func supports(bridgeID: String) -> Bool {
    return supportedBridges.isEmpty || supportedBridges.contains(bridgeID)
  }
}
