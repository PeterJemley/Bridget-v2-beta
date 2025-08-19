//
//  MLTypes.swift
//  Bridget
//
//  ## Purpose
//  Central shared types and constants for ML pipeline.
//  IMPORTANT: If you change feature/target shapes or horizon list here, update all pipeline usages.
//
//  ## Dependencies
//  CoreML framework, Foundation framework
//
//  ## Integration Points
//  Used by FeatureEngineeringService, TrainPrepService, and other ML pipeline services
//  for consistent data types, error handling, and shape constants.
//
//  ## Key Features
//  - FeatureVector: Immutable struct for ML features
//  - ProbeTickRaw: Raw data structure for probe ticks
//  - Error types: CoreMLError, DataValidationResult
//  - Constants: Feature dimensions, horizons, and shapes
//
//  ## IMPORTANT
//  Changes to feature/target shapes or horizon constants MUST be reflected throughout
//  the entire ML pipeline, including training, feature engineering, and inference.
//

import CoreML
import Foundation

// MARK: - Constants

/// Feature dimension for ML model input
public let featureDimension = 14  // Increased from 12 to include speed fields

/// Target dimension for ML model output
public let targetDimension = 1

/// Default prediction horizons in minutes
public let defaultHorizons: [Int] = [0, 3, 6, 9, 12]

/// Default input shape for ML model [batch_size, feature_count]
public let defaultInputShape: [Int] = [1, featureDimension]

/// Default output shape for ML model [batch_size, target_count]
public let defaultOutputShape: [Int] = [1, targetDimension]

// MARK: - Data Models

/// Raw probe tick data structure from NDJSON
public struct ProbeTickRaw: Codable {
  public let v: Int?
  public let ts_utc: String
  public let bridge_id: Int
  public let cross_k: Double?
  public let cross_n: Double?
  public let via_routable: Double?
  public let via_penalty_sec: Double?
  public let gate_anom: Double?
  public let alternates_total: Double?
  public let alternates_avoid: Double?
  public let open_label: Int
  public let detour_delta: Double?
  public let detour_frac: Double?
  // Speed-related fields for traffic analysis
  public let current_traffic_speed: Double?
  public let normal_traffic_speed: Double?

  public init(v: Int?, ts_utc: String, bridge_id: Int, cross_k: Double?, cross_n: Double?, via_routable: Double?, via_penalty_sec: Double?, gate_anom: Double?, alternates_total: Double?, alternates_avoid: Double?, open_label: Int, detour_delta: Double?, detour_frac: Double?, current_traffic_speed: Double? = nil, normal_traffic_speed: Double? = nil) {
    self.v = v
    self.ts_utc = ts_utc
    self.bridge_id = bridge_id
    self.cross_k = cross_k
    self.cross_n = cross_n
    self.via_routable = via_routable
    self.via_penalty_sec = via_penalty_sec
    self.gate_anom = gate_anom
    self.alternates_total = alternates_total
    self.alternates_avoid = alternates_avoid
    self.open_label = open_label
    self.detour_delta = detour_delta
    self.detour_frac = detour_frac
    self.current_traffic_speed = current_traffic_speed
    self.normal_traffic_speed = normal_traffic_speed
  }
}

/// Feature vector for ML training and inference
public struct FeatureVector {
  public let bridge_id: Int
  public let horizon_min: Int
  public let min_sin: Double
  public let min_cos: Double
  public let dow_sin: Double
  public let dow_cos: Double
  public let open_5m: Double
  public let open_30m: Double
  public let detour_delta: Double
  public let cross_rate: Double
  public let via_routable: Double
  public let via_penalty: Double
  public let gate_anom: Double
  public let detour_frac: Double
  // Speed-related features
  public let current_speed: Double
  public let normal_speed: Double
  public let target: Int

  public init(bridge_id: Int,
              horizon_min: Int,
              min_sin: Double,
              min_cos: Double,
              dow_sin: Double,
              dow_cos: Double,
              open_5m: Double,
              open_30m: Double,
              detour_delta: Double,
              cross_rate: Double,
              via_routable: Double,
              via_penalty: Double,
              gate_anom: Double,
              detour_frac: Double,
              current_speed: Double,
              normal_speed: Double,
              target: Int)
  {
    self.bridge_id = bridge_id
    self.horizon_min = horizon_min
    self.min_sin = min_sin
    self.min_cos = min_cos
    self.dow_sin = dow_sin
    self.dow_cos = dow_cos
    self.open_5m = open_5m
    self.open_30m = open_30m
    self.detour_delta = detour_delta
    self.cross_rate = cross_rate
    self.via_routable = via_routable
    self.via_penalty = via_penalty
    self.gate_anom = gate_anom
    self.detour_frac = detour_frac
    self.current_speed = current_speed
    self.normal_speed = normal_speed
    self.target = target
  }

  /// Converts this feature vector to MLMultiArray format for Core ML training/inference.
  ///
  /// The shape is [1, featureCount] for single samples.
  ///
  /// - Returns: MLMultiArray containing the feature values
  /// - Throws: Error if MLMultiArray creation fails
  public func toMLMultiArray() throws -> MLMultiArray {
    let features = [
      min_sin, min_cos, dow_sin, dow_cos,
      open_5m, open_30m, detour_delta, cross_rate,
      via_routable, via_penalty, gate_anom, detour_frac,
      current_speed, normal_speed,
    ]

    let array = try MLMultiArray(shape: [1, NSNumber(value: features.count)], dataType: .double)

    for (i, value) in features.enumerated() {
      array[[0, i] as [NSNumber]] = NSNumber(value: value)
    }

    return array
  }

  /// Creates a target MLMultiArray for training.
  ///
  /// - Returns: MLMultiArray containing the target value
  /// - Throws: Error if MLMultiArray creation fails
  public func toTargetMLMultiArray() throws -> MLMultiArray {
    let array = try MLMultiArray(shape: [1, 1], dataType: .double)
    array[[0, 0] as [NSNumber]] = NSNumber(value: target)
    return array
  }

  /// Number of features in the vector
  public static let featureCount = featureDimension

  /// Names of features for debugging and analysis
  public static let featureNames = [
    "min_sin", "min_cos", "dow_sin", "dow_cos",
    "open_5m", "open_30m", "detour_delta", "cross_rate",
    "via_routable", "via_penalty", "gate_anom", "detour_frac",
    "current_speed", "normal_speed",
  ]
}

// MARK: - Error Types

/// Core ML specific errors
public enum CoreMLError: Error, LocalizedError {
  case invalidModel
  case trainingFailed(String)
  case dataConversionFailed
  case modelCreationFailed

  public var errorDescription: String? {
    switch self {
    case .invalidModel:
      return "Invalid Core ML model"
    case let .trainingFailed(reason):
      return "Training failed: \(reason)"
    case .dataConversionFailed:
      return "Failed to convert data to MLMultiArray format"
    case .modelCreationFailed:
      return "Failed to create Core ML model"
    }
  }
}

/// Data validation result structure for pipeline validation.
///
/// Tracks counts of various validation metrics and provides a summary.
public struct DataValidationResult {
  public var totalRecords: Int = 0
  public var bridgeCount: Int = 0
  public var invalidBridgeIds: Int = 0
  public var invalidOpenLabels: Int = 0
  public var invalidCrossRatios: Int = 0
  public var recordsPerBridge: [Int: Int] = [:]
  public var isValid: Bool = false

  // Enhanced validation tracking
  public var errors: [String] = []
  public var warnings: [String] = []
  public var timestampRange: (first: Date?, last: Date?) = (nil, nil)
  public var horizonCoverage: [Int: Int] = [:]
  public var dataQualityMetrics: DataQualityMetrics = .init(dataCompleteness: 0.0,
                                                            timestampValidity: 0.0,
                                                            bridgeIDValidity: 0.0,
                                                            speedDataValidity: 0.0,
                                                            duplicateCount: 0,
                                                            missingFieldsCount: 0)

  public init(totalRecords: Int = 0,
              bridgeCount: Int = 0,
              invalidBridgeIds: Int = 0,
              invalidOpenLabels: Int = 0,
              invalidCrossRatios: Int = 0,
              recordsPerBridge: [Int: Int] = [:],
              isValid: Bool = false,
              errors: [String] = [],
              warnings: [String] = [],
              timestampRange: (first: Date?, last: Date?) = (nil, nil),
              horizonCoverage: [Int: Int] = [:],
              dataQualityMetrics: DataQualityMetrics = DataQualityMetrics(dataCompleteness: 0.0,
                                                                          timestampValidity: 0.0,
                                                                          bridgeIDValidity: 0.0,
                                                                          speedDataValidity: 0.0,
                                                                          duplicateCount: 0,
                                                                          missingFieldsCount: 0))
  {
    self.totalRecords = totalRecords
    self.bridgeCount = bridgeCount
    self.invalidBridgeIds = invalidBridgeIds
    self.invalidOpenLabels = invalidOpenLabels
    self.invalidCrossRatios = invalidCrossRatios
    self.recordsPerBridge = recordsPerBridge
    self.isValid = isValid
    self.errors = errors
    self.warnings = warnings
    self.timestampRange = timestampRange
    self.horizonCoverage = horizonCoverage
    self.dataQualityMetrics = dataQualityMetrics
  }

  public var validRecordCount: Int {
    totalRecords - invalidBridgeIds - invalidOpenLabels - invalidCrossRatios
  }

  public var validationRate: Double {
    totalRecords > 0 ? Double(validRecordCount) / Double(totalRecords) : 0.0
  }

  public var summary: String {
    """
    Data Validation Summary:
    - Total Records: \(totalRecords)
    - Valid Records: \(validRecordCount)
    - Validation Rate: \(String(format: "%.1f%%", validationRate * 100))
    - Bridges: \(bridgeCount)
    - Errors: \(errors.count)
    - Warnings: \(warnings.count)
    - Valid: \(isValid ? "Yes" : "No")
    """
  }

  public var detailedSummary: String {
    """
    Detailed Validation Summary:
    - Total Records: \(totalRecords)
    - Valid Records: \(validRecordCount)
    - Validation Rate: \(String(format: "%.1f%%", validationRate * 100))
    - Bridges: \(bridgeCount)
    - Invalid Bridge IDs: \(invalidBridgeIds)
    - Invalid Open Labels: \(invalidOpenLabels)
    - Invalid Cross Ratios: \(invalidCrossRatios)
    - Timestamp Range: \(timestampRange.first?.description ?? "None") to \(timestampRange.last?.description ?? "None")
    - Horizon Coverage: \(horizonCoverage.map { "\($0.key)min: \($0.value)" }.joined(separator: ", "))
    - Data Quality: Completeness: \(String(format: "%.1f%%", dataQualityMetrics.dataCompleteness * 100)), Speed: \(String(format: "%.1f%%", dataQualityMetrics.speedDataValidity * 100))
    - Errors: \(errors.joined(separator: "; "))
    - Warnings: \(warnings.joined(separator: "; "))
    - Valid: \(isValid ? "Yes" : "No")
    """
  }
}

// DataQualityMetrics is now defined in DataStatisticsService.swift

/// Model validation result structure
public struct ModelValidationResult {
  public var modelPath: String = ""
  public var modelDescription: MLModelDescription?
  public var samplePrediction: MLFeatureProvider?
  public var isValid: Bool = false

  public init(modelPath: String = "",
              modelDescription: MLModelDescription? = nil,
              samplePrediction: MLFeatureProvider? = nil,
              isValid: Bool = false)
  {
    self.modelPath = modelPath
    self.modelDescription = modelDescription
    self.samplePrediction = samplePrediction
    self.isValid = isValid
  }

  public var summary: String {
    """
    Model Validation Summary:
    - Model Path: \(modelPath)
    - Valid: \(isValid ? "Yes" : "No")
    - Description: \(modelDescription?.inputDescriptionsByName.keys.joined(separator: ", ") ?? "Unknown")
    """
  }
}

// MARK: - Pipeline Types

/// Pipeline operation types for notifications and monitoring.
public enum PipelineOperation: String, CaseIterable {
  /// Data population operation
  case dataPopulation = "Data Population"
  /// Data export operation
  case dataExport = "Data Export"
  /// Maintenance operation
  case maintenance = "Maintenance"
  /// Health check operation
  case healthCheck = "Health Check"
}

/// Pipeline health issue types for monitoring and alerts.
public enum PipelineHealthIssue: String, CaseIterable {
  /// Data is stale
  case dataStale = "Data Stale"
  /// Export operation failed
  case exportFailed = "Export Failed"
  /// Low disk space warning
  case lowDiskSpace = "Low Disk Space"
  /// Background task expired
  case backgroundTaskExpired = "Background Task Expired"
}

/// Notification type categories for ML pipeline events.
public enum NotificationType: String, CaseIterable {
  /// Success notification
  case success = "Success"
  /// Failure notification
  case failure = "Failure"
  /// Progress notification
  case progress = "Progress"
  /// Health notification
  case health = "Health"
}

// MARK: - Configuration Types

/// Feature engineering configuration
public struct FeatureEngineeringConfiguration {
  public let horizons: [Int]
  public let deterministicSeed: UInt64
  public let enableProgressReporting: Bool

  public init(horizons: [Int] = defaultHorizons,
              deterministicSeed: UInt64 = 42,
              enableProgressReporting: Bool = true)
  {
    self.horizons = horizons
    self.deterministicSeed = deterministicSeed
    self.enableProgressReporting = enableProgressReporting
  }
}

// MARK: - Enhanced Configuration

/// Enhanced pipeline configuration with all refinement options
public struct EnhancedPipelineConfig: Codable {
  // Core settings
  public let inputPath: String
  public let outputDirectory: String
  public let trainingConfig: TrainingConfig

  // Parallelization settings
  public let enableParallelization: Bool
  public let maxConcurrentHorizons: Int
  public let batchSize: Int

  // Retry and recovery settings
  public let maxRetryAttempts: Int
  public let retryBackoffMultiplier: Double
  public let enableCheckpointing: Bool
  public let checkpointDirectory: String?

  // Validation gates
  public let dataQualityThresholds: DataQualityThresholds
  public let modelPerformanceThresholds: ModelPerformanceThresholds

  // Monitoring and logging
  public let enableDetailedLogging: Bool
  public let enableMetricsExport: Bool
  public let metricsExportPath: String?

  // Performance tuning
  public let enableProgressReporting: Bool
  public let memoryOptimizationLevel: MemoryOptimizationLevel

  public init(inputPath: String = "minutes_2025-01-27.ndjson",
              outputDirectory: String = FileManager.default.currentDirectoryPath,
              trainingConfig: TrainingConfig = .production,
              enableParallelization: Bool = true,
              maxConcurrentHorizons: Int = 4,
              batchSize: Int = 1000,
              maxRetryAttempts: Int = 3,
              retryBackoffMultiplier: Double = 2.0,
              enableCheckpointing: Bool = true,
              checkpointDirectory: String? = nil,
              dataQualityThresholds: DataQualityThresholds = .default,
              modelPerformanceThresholds: ModelPerformanceThresholds = .default,
              enableDetailedLogging: Bool = true,
              enableMetricsExport: Bool = false,
              metricsExportPath: String? = nil,
              enableProgressReporting: Bool = true,
              memoryOptimizationLevel: MemoryOptimizationLevel = .balanced)
  {
    self.inputPath = inputPath
    self.outputDirectory = outputDirectory
    self.trainingConfig = trainingConfig
    self.enableParallelization = enableParallelization
    self.maxConcurrentHorizons = maxConcurrentHorizons
    self.batchSize = batchSize
    self.maxRetryAttempts = maxRetryAttempts
    self.retryBackoffMultiplier = retryBackoffMultiplier
    self.enableCheckpointing = enableCheckpointing
    self.checkpointDirectory = checkpointDirectory
    self.dataQualityThresholds = dataQualityThresholds
    self.modelPerformanceThresholds = modelPerformanceThresholds
    self.enableDetailedLogging = enableDetailedLogging
    self.enableMetricsExport = enableMetricsExport
    self.metricsExportPath = metricsExportPath
    self.enableProgressReporting = enableProgressReporting
    self.memoryOptimizationLevel = memoryOptimizationLevel
  }

  /// Load configuration from JSON file
  public static func load(from path: String) throws -> EnhancedPipelineConfig {
    let data = try Data(contentsOf: URL(fileURLWithPath: path))
    return try JSONDecoder.bridgeDecoder().decode(EnhancedPipelineConfig.self, from: data)
  }

  /// Save configuration to JSON file
  public func save(to path: String) throws {
    let data = try JSONEncoder.bridgeEncoder().encode(self)
    try data.write(to: URL(fileURLWithPath: path))
  }
}

/// Data quality thresholds for pipeline gates
public struct DataQualityThresholds: Codable {
  public let maxNaNRate: Double
  public let minValidationRate: Double
  public let maxInvalidRecordRate: Double
  public let minDataVolume: Int

  public static let `default` = DataQualityThresholds(maxNaNRate: 0.05,
                                                      minValidationRate: 0.95,
                                                      maxInvalidRecordRate: 0.02,
                                                      minDataVolume: 1000)

  public init(maxNaNRate: Double = 0.05,
              minValidationRate: Double = 0.95,
              maxInvalidRecordRate: Double = 0.02,
              minDataVolume: Int = 1000)
  {
    self.maxNaNRate = maxNaNRate
    self.minValidationRate = minValidationRate
    self.maxInvalidRecordRate = maxInvalidRecordRate
    self.minDataVolume = minDataVolume
  }
}

/// Model performance thresholds for pipeline gates
public struct ModelPerformanceThresholds: Codable {
  public let minAccuracy: Double
  public let maxLoss: Double
  public let minF1Score: Double

  public static let `default` = ModelPerformanceThresholds(minAccuracy: 0.75,
                                                           maxLoss: 0.5,
                                                           minF1Score: 0.70)

  public init(minAccuracy: Double = 0.75,
              maxLoss: Double = 0.5,
              minF1Score: Double = 0.70)
  {
    self.minAccuracy = minAccuracy
    self.maxLoss = maxLoss
    self.minF1Score = minF1Score
  }
}

/// Memory optimization levels
public enum MemoryOptimizationLevel: String, Codable, CaseIterable {
  case minimal      // Fastest, highest memory usage
  case balanced    // Balanced performance/memory
  case aggressive // Slowest, lowest memory usage

  public var batchSizeMultiplier: Double {
    switch self {
    case .minimal: return 2.0
    case .balanced: return 1.0
    case .aggressive: return 0.5
    }
  }
}

/// Pipeline execution state for resumable pipelines
public struct PipelineExecutionState: Codable {
  public let pipelineId: String
  public let startTime: Date
  public var lastCheckpoint: Date?
  public var completedStages: Set<PipelineStage>
  public var currentStage: PipelineStage?
  public var stageProgress: Double
  public var error: String?
  public var metadata: [String: String]

  public init(pipelineId: String,
              startTime: Date = Date(),
              lastCheckpoint: Date? = nil,
              completedStages: Set<PipelineStage> = [],
              currentStage: PipelineStage? = nil,
              stageProgress: Double = 0.0,
              error: String? = nil,
              metadata: [String: String] = [:])
  {
    self.pipelineId = pipelineId
    self.startTime = startTime
    self.lastCheckpoint = lastCheckpoint
    self.completedStages = completedStages
    self.currentStage = currentStage
    self.stageProgress = stageProgress
    self.error = error
    self.metadata = metadata
  }
}

/// Pipeline stages for checkpointing and progress tracking
public enum PipelineStage: String, Codable, CaseIterable {
  case dataLoading = "data_loading"
  case dataValidation = "data_validation"
  case featureEngineering = "feature_engineering"
  case mlMultiArrayConversion = "ml_multi_array_conversion"
  case modelTraining = "model_training"
  case modelValidation = "model_validation"
  case artifactExport = "artifact_export"

  public var displayName: String {
    switch self {
    case .dataLoading: return "Data Loading"
    case .dataValidation: return "Data Validation"
    case .featureEngineering: return "Feature Engineering"
    case .mlMultiArrayConversion: return "MLMultiArray Conversion"
    case .modelTraining: return "Model Training"
    case .modelValidation: return "Model Validation"
    case .artifactExport: return "Artifact Export"
    }
  }
}
