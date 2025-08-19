//
//  Protocols.swift
//  Bridget
//
//  ## Purpose
//  Central protocols for ML pipeline progress/status/error reporting.
//  All ML pipeline services implement these protocols for consistent progress tracking.
//
//  ## Dependencies
//  Foundation framework
//
//  ## Integration Points
//  Used by TrainPrepService, FeatureEngineeringService, and MLPipelineViewModel
//  for progress reporting and status updates throughout the ML pipeline.
//
//  ## Key Features
//  - TrainPrepProgressDelegate: Training data preparation progress
//  - CoreMLTrainingProgressDelegate: Core ML training pipeline progress
//  - FeatureEngineeringProgressDelegate: Feature engineering progress
//

import Foundation

// MARK: - Training Data Preparation Progress

/// Protocol for reporting training data preparation progress
public protocol TrainPrepProgressDelegate: AnyObject {
  func trainPrepDidStart()
  func trainPrepDidLoadData(_ count: Int)
  func trainPrepDidProcessHorizon(_ horizon: Int, featureCount: Int)
  func trainPrepDidSaveHorizon(_ horizon: Int, to path: String)
  func trainPrepDidComplete()
  func trainPrepDidFail(_ error: Error)
}

// MARK: - Core ML Training Progress

/// Protocol for reporting Core ML training pipeline progress
@MainActor
public protocol CoreMLTrainingProgressDelegate: AnyObject, Sendable {
  func trainingDidStart()
  func trainingDidLoadData(_ count: Int)
  func trainingDidPrepareData(_ count: Int)
  func trainingDidUpdateProgress(_ progress: Double)
  func trainingDidComplete(_ modelPath: String)
  func trainingDidFail(_ error: Error)

  func pipelineDidStart()
  func pipelineDidProcessData(_ fileCount: Int)
  func pipelineDidStartTraining(_ horizon: Int)
  func pipelineDidCompleteTraining(_ horizon: Int, modelPath: String)
  func pipelineDidComplete(_ models: [Int: String])
}

// MARK: - Feature Engineering Progress

/// Protocol for reporting feature engineering progress
public protocol FeatureEngineeringProgressDelegate: AnyObject {
  func featureEngineeringDidStart()
  func featureEngineeringDidProcessHorizon(_ horizon: Int, featureCount: Int)
  func featureEngineeringDidComplete(_ totalFeatures: Int)
  func featureEngineeringDidFail(_ error: Error)
}

// MARK: - Persistence Protocols

/// Protocol defining persistence operations for bridge events.
/// Implementers handle saving, loading, and managing bridge event data persistence.
public protocol BridgeEventPersistenceServiceProtocol: AnyObject {
  func saveEvent(_ event: Data, withID id: String) throws
  func loadEvent(withID id: String) throws -> Data?
  func deleteEvent(withID id: String) throws
  func fetchAllEventIDs() throws -> [String]

  // BridgeEvent-specific methods
  func save(events: [BridgeEvent]) throws
  func fetchAllEvents() throws -> [BridgeEvent]
  func deleteAllEvents() throws
}

// MARK: - Enhanced Pipeline Progress

/// Enhanced pipeline progress delegate with detailed stage tracking
@MainActor
public protocol EnhancedPipelineProgressDelegate: AnyObject, Sendable {
  // Stage lifecycle
  func pipelineDidStartStage(_ stage: PipelineStage)
  func pipelineDidUpdateStageProgress(_ stage: PipelineStage, progress: Double)
  func pipelineDidCompleteStage(_ stage: PipelineStage)
  func pipelineDidFailStage(_ stage: PipelineStage, error: Error)

  // Checkpointing
  func pipelineDidCreateCheckpoint(_ stage: PipelineStage, at path: String)
  func pipelineDidResumeFromCheckpoint(_ stage: PipelineStage, at path: String)

  // Validation gates
  func pipelineDidEvaluateDataQualityGate(_ result: DataValidationResult) -> Bool
  func pipelineDidEvaluateModelPerformanceGate(_ metrics: ModelPerformanceMetrics) -> Bool

  // Performance metrics
  func pipelineDidUpdateMetrics(_ metrics: PipelineMetrics)
  func pipelineDidExportMetrics(to path: String)

  // Overall pipeline
  func pipelineDidComplete(_ models: [Int: String])
  func pipelineDidFail(_ error: Error)
}

/// Protocol for retry mechanisms
public protocol RetryableOperation {
  func shouldRetry(_ error: Error, attempt: Int) -> Bool
  func retryDelay(for attempt: Int) -> TimeInterval
}

/// Protocol for checkpoint management
public protocol CheckpointManager {
  func createCheckpoint(for stage: PipelineStage, data: Data) throws -> String
  func loadCheckpoint(for stage: PipelineStage) throws -> Data?
  func deleteCheckpoint(for stage: PipelineStage) throws
  func listCheckpoints() -> [String]
}

// MARK: - Data Structures

/// Comprehensive pipeline metrics
public struct PipelineMetrics: Codable {
  public var stageDurations: [PipelineStage: TimeInterval]
  public var memoryUsage: [PipelineStage: Int] // MB
  public var recordCounts: [PipelineStage: Int]
  public var errorCounts: [PipelineStage: Int]
  public var validationRates: [PipelineStage: Double]
  public let timestamp: Date

  public init(stageDurations: [PipelineStage: TimeInterval] = [:],
              memoryUsage: [PipelineStage: Int] = [:],
              recordCounts: [PipelineStage: Int] = [:],
              errorCounts: [PipelineStage: Int] = [:],
              validationRates: [PipelineStage: Double] = [:],
              timestamp: Date = Date())
  {
    self.stageDurations = stageDurations
    self.memoryUsage = memoryUsage
    self.recordCounts = recordCounts
    self.errorCounts = errorCounts
    self.validationRates = validationRates
    self.timestamp = timestamp
  }
}

/// Model performance metrics for validation gates
public struct ModelPerformanceMetrics: Codable {
  public let accuracy: Double
  public let loss: Double
  public let f1Score: Double
  public let precision: Double
  public let recall: Double
  public let confusionMatrix: [[Int]]

  public init(accuracy: Double,
              loss: Double,
              f1Score: Double,
              precision: Double,
              recall: Double,
              confusionMatrix: [[Int]])
  {
    self.accuracy = accuracy
    self.loss = loss
    self.f1Score = f1Score
    self.precision = precision
    self.recall = recall
    self.confusionMatrix = confusionMatrix
  }
}
