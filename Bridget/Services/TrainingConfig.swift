//
//  TrainingConfig.swift
//  Bridget
//
//  ## Purpose
//  Deterministic training configuration for Core ML model training
//  Ensures reproducible training results across different runs
//
//  ## Dependencies
//  CoreML framework for model configuration
//
//  ## Integration Points
//  Used by TrainPrepService for Core ML training
//  Configures ANE utilization and training parameters
//
//  ## Key Features
//  Deterministic seed configuration
//  ANE utilization settings
//  Batch size and epoch configuration
//  Performance optimization settings
//

import CoreML
import Foundation

// MARK: - Training Configuration

public struct TrainingConfig: Codable {
  /// Deterministic seed for reproducible training
  public let deterministicSeed: UInt64
  
  /// Batch size for training
  public let batchSize: Int
  
  /// Maximum number of training epochs
  public let maxEpochs: Int
  
  /// Learning rate for training
  public let learningRate: Double
  
  /// Early stopping patience (epochs without improvement)
  public let earlyStoppingPatience: Int
  
  /// Whether to use Apple Neural Engine (ANE)
  public let useANE: Bool
  
  /// Model input/output shapes
  public let inputShape: [Int]
  public let outputShape: [Int]
  
  /// Feature dimensions
  public let featureDimensions: Int
  
  /// Prediction horizons
  public let horizons: [Int]
  
  public init(deterministicSeed: UInt64 = 42,
              batchSize: Int = 32,
              maxEpochs: Int = 100,
              learningRate: Double = 0.001,
              earlyStoppingPatience: Int = 10,
              useANE: Bool = true,
              inputShape: [Int] = [1, 64],
              outputShape: [Int] = [1, 1],
              featureDimensions: Int = 64,
              horizons: [Int] = defaultHorizons) {
    self.deterministicSeed = deterministicSeed
    self.batchSize = batchSize
    self.maxEpochs = maxEpochs
    self.learningRate = learningRate
    self.earlyStoppingPatience = earlyStoppingPatience
    self.useANE = useANE
    self.inputShape = inputShape
    self.outputShape = outputShape
    self.featureDimensions = featureDimensions
    self.horizons = horizons
  }
  
  /// Default configuration for production training
  public static let production = TrainingConfig(
    deterministicSeed: 42,
    batchSize: 32,
    maxEpochs: 100,
    learningRate: 0.001,
    earlyStoppingPatience: 10,
    useANE: true,
    featureDimensions: 64,
    horizons: defaultHorizons
  )
  
  /// Configuration for development/testing
  public static let development = TrainingConfig(
    deterministicSeed: 123,
    batchSize: 16,
    maxEpochs: 50,
    learningRate: 0.01,
    earlyStoppingPatience: 5,
    useANE: false,
    featureDimensions: 64,
    horizons: [0, 3]
  )
  
  /// Configuration for quick validation
  public static let validation = TrainingConfig(
    deterministicSeed: 999,
    batchSize: 8,
    maxEpochs: 10,
    learningRate: 0.01,
    earlyStoppingPatience: 3,
    useANE: false,
    featureDimensions: 64,
    horizons: [0]
  )
}

// MARK: - Core ML Configuration

public extension TrainingConfig {
  /// Creates MLModelConfiguration with deterministic settings
  func createMLModelConfiguration() -> MLModelConfiguration {
    let config = MLModelConfiguration()
    
    // Set deterministic compute units
    if useANE {
      config.computeUnits = .all
    } else {
      config.computeUnits = .cpuAndGPU
    }
    
    // Enable low precision for better performance
    config.allowLowPrecisionAccumulationOnGPU = true
    
    return config
  }
  
  /// Creates training parameters dictionary
  func createTrainingParameters() -> [String: Any] {
    return [
      "deterministicSeed": deterministicSeed,
      "batchSize": batchSize,
      "maxEpochs": maxEpochs,
      "learningRate": learningRate,
      "earlyStoppingPatience": earlyStoppingPatience,
      "useANE": useANE,
      "inputShape": inputShape,
      "outputShape": outputShape,
      "featureDimensions": featureDimensions,
      "horizons": horizons
    ]
  }
}

// MARK: - Schema Hash Generation

public extension TrainingConfig {
  /// Generates a schema hash for parity validation
  func generateSchemaHash() -> String {
    let schemaData = """
    featureDimensions:\(featureDimensions)
    inputShape:\(inputShape.map(String.init).joined(separator:","))
    outputShape:\(outputShape.map(String.init).joined(separator:","))
    horizons:\(horizons.sorted().map(String.init).joined(separator:","))
    batchSize:\(batchSize)
    maxEpochs:\(maxEpochs)
    learningRate:\(learningRate)
    useANE:\(useANE)
    """
    
    let data = schemaData.data(using: .utf8) ?? Data()
    let hash = data.sha256()
    return hash.map { String(format: "%02x", $0) }.joined()
  }
}

// MARK: - Performance Budgets

public extension TrainingConfig {
  /// Performance budget for training stages
  struct PerformanceBudget {
    public let parseTimeMs: Double
    public let featureEngineeringTimeMs: Double
    public let mlMultiArrayConversionTimeMs: Double
    public let trainingTimeMs: Double
    public let validationTimeMs: Double
    public let peakMemoryMB: Double
    
    public init(parseTimeMs: Double = 1000,
                featureEngineeringTimeMs: Double = 5000,
                mlMultiArrayConversionTimeMs: Double = 500,
                trainingTimeMs: Double = 30000,
                validationTimeMs: Double = 2000,
                peakMemoryMB: Double = 512) {
      self.parseTimeMs = parseTimeMs
      self.featureEngineeringTimeMs = featureEngineeringTimeMs
      self.mlMultiArrayConversionTimeMs = mlMultiArrayConversionTimeMs
      self.trainingTimeMs = trainingTimeMs
      self.validationTimeMs = validationTimeMs
      self.peakMemoryMB = peakMemoryMB
    }
    
    /// Default production performance budget
    public static let production = PerformanceBudget(
      parseTimeMs: 1000,
      featureEngineeringTimeMs: 5000,
      mlMultiArrayConversionTimeMs: 500,
      trainingTimeMs: 30000,
      validationTimeMs: 2000,
      peakMemoryMB: 512
    )
    
    /// Relaxed development performance budget
    public static let development = PerformanceBudget(
      parseTimeMs: 2000,
      featureEngineeringTimeMs: 10000,
      mlMultiArrayConversionTimeMs: 1000,
      trainingTimeMs: 60000,
      validationTimeMs: 5000,
      peakMemoryMB: 1024
    )
  }
  
  /// Returns appropriate performance budget for this configuration
  func getPerformanceBudget() -> PerformanceBudget {
    if self.deterministicSeed == TrainingConfig.production.deterministicSeed &&
       self.batchSize == TrainingConfig.production.batchSize &&
       self.maxEpochs == TrainingConfig.production.maxEpochs {
      return PerformanceBudget.production
    } else if self.deterministicSeed == TrainingConfig.development.deterministicSeed &&
              self.batchSize == TrainingConfig.development.batchSize &&
              self.maxEpochs == TrainingConfig.development.maxEpochs {
      return PerformanceBudget.development
    } else {
      return PerformanceBudget.development
    }
  }
}

// MARK: - Utility Extensions

private extension Data {
  func sha256() -> Data {
    // Simple hash implementation for now - can be enhanced later
    var hash = Data()
    for byte in self {
      hash.append(byte ^ 0x42) // Simple XOR-based hash
    }
    return hash
  }
}

// MLModelConfiguration extension removed to avoid duplication
