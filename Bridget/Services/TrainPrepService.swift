//
//  TrainPrepService.swift
//  Bridget
//
//  ## Purpose
//  Step 5: Orchestrator Service - Coordinator only, no heavy logic
//  Ties Steps 2-4 together: FeatureEngineering → Validation → CoreMLTraining
//
//  ## Dependencies
//  FeatureEngineeringService (Step 2), DataValidationService (Step 3), CoreMLTraining (Step 4)
//
//  ## Integration Points
//  Single entry point: runPipeline(from:config:progress:) -> (model: MLModel, report: TrainingReport)
//  Call sequence: parse NDJSON → FeatureEngineering → Validation → CoreMLTraining.train/evaluate
//
//  ## Key Features
//  Orchestration-only design (no heavy logic)
//  Progress via delegates
//  Comprehensive TrainingReport with timings, metrics, validation summaries, seeds, shapes
//  E2E "happy path" completes in-memory with model + report
//

import CoreML
import Foundation
import OSLog

// MARK: - Main Orchestrator Service

/// Step 5: Orchestrator Service - Coordinates Steps 2-4 modules
public class TrainPrepService {
  private let logger = Logger(subsystem: "com.peterjemley.Bridget",
                              category: "TrainPrepService")

  public init() {}

  /// Single entry point for the complete ML pipeline
  /// - Parameters:
  ///   - ndjsonURL: URL to NDJSON data file
  ///   - config: Core ML training configuration
  ///   - progress: Optional progress delegate for real-time updates
  /// - Returns: Tuple of trained MLModel and comprehensive TrainingReport
  /// - Throws: Various errors from Steps 2-4 modules
  public func runPipeline(from ndjsonURL: URL,
                          config: CoreMLTrainingConfig,
                          progress: TrainPrepProgressDelegate? = nil,
                          enhancedProgress: EnhancedPipelineProgressDelegate? = nil) async throws -> (model: MLModel, report: TrainingReport)
  {
    let startTime = Date()
    logger.info(
      "🚀 Starting ML pipeline with config: \(String(describing: config))"
    )
    logger.info("📁 Input file: \(ndjsonURL.path)")

    // Initialize timing tracking
    var timings = PipelineTimings(totalDuration: 0,
                                  dataLoadingTime: 0,
                                  dataValidationTime: 0,
                                  featureEngineeringTime: 0,
                                  trainingTime: 0,
                                  validationTime: 0)

    do {
      // Step 1: Parse NDJSON data
      logger.info("📊 Starting data loading stage...")
      await progress?.trainPrepDidStart()
      await enhancedProgress?.pipelineDidStartStage(.dataLoading)
      await enhancedProgress?.pipelineDidUpdateStageProgress(.dataLoading,
                                                             progress: 0.0)
      let dataLoadingStart = Date()

      let ticks = try await parseNDJSON(from: ndjsonURL)
      timings.dataLoadingTime = Date().timeIntervalSince(dataLoadingStart)

      await enhancedProgress?.pipelineDidUpdateStageProgress(.dataLoading,
                                                             progress: 1.0)
      await enhancedProgress?.pipelineDidCompleteStage(.dataLoading)
      await progress?.trainPrepDidLoadData(ticks.count)
      logger.info(
        "✅ Data loading completed: \(ticks.count) probe ticks loaded in \(timings.dataLoadingTime)s"
      )

      // Step 2: Data Validation (Step 3 module)
      logger.info("🔍 Starting data validation stage...")
      await enhancedProgress?.pipelineDidStartStage(.dataValidation)
      await enhancedProgress?.pipelineDidUpdateStageProgress(.dataValidation,
                                                             progress: 0.0)
      let validationStart = Date()

      let validationService = DataValidationService()
      logger.info("🔍 Running async validation on \(ticks.count) ticks...")
      let validationResult = await validationService.validateAsync(
        ticks: ticks
      )

      timings.dataValidationTime = Date().timeIntervalSince(
        validationStart
      )
      logger.info(
        "🔍 Validation completed in \(timings.dataValidationTime)s"
      )
      logger.info(
        "🔍 Validation result: \(validationResult.totalRecords) total, \(validationResult.validRecordCount) valid, \(validationResult.errors.count) errors"
      )

      // Check data quality gate
      logger.info("🔍 Evaluating data quality gate...")
      let shouldContinue =
        await enhancedProgress?.pipelineDidEvaluateDataQualityGate(
          validationResult
        ) ?? true
      logger.info(
        "🔍 Data quality gate result: \(shouldContinue ? "PASS" : "FAIL")"
      )

      guard shouldContinue else {
        let error = CoreMLTrainingError.featureDrift(description: "Data quality gate failed",
                                                     expectedCount: validationResult.totalRecords,
                                                     actualCount: validationResult.validRecordCount)
        logger.error(
          "❌ Data quality gate failed: \(error.localizedDescription)"
        )
        await enhancedProgress?.pipelineDidFailStage(.dataValidation,
                                                     error: error)
        throw error
      }

      guard validationResult.isValid else {
        let error = CoreMLTrainingError.featureDrift(description:
          "Data validation failed: \(validationResult.errors.joined(separator: ", "))",
          expectedCount: validationResult.totalRecords,
          actualCount: validationResult.validRecordCount)
        logger.error(
          "❌ Data validation failed: \(error.localizedDescription)"
        )
        await enhancedProgress?.pipelineDidFailStage(.dataValidation,
                                                     error: error)
        throw error
      }

      await enhancedProgress?.pipelineDidUpdateStageProgress(.dataValidation,
                                                             progress: 1.0)
      await enhancedProgress?.pipelineDidCompleteStage(.dataValidation)
      logger.info(
        "✅ Data validation passed with \(validationResult.totalRecords) records"
      )

      // Step 3: Feature Engineering (Step 2 module)
      logger.info("🔧 Starting feature engineering stage...")
      await enhancedProgress?.pipelineDidStartStage(.featureEngineering)
      await enhancedProgress?.pipelineDidUpdateStageProgress(.featureEngineering,
                                                             progress: 0.0)
      let featureStart = Date()

      let featureConfig = FeatureEngineeringConfiguration(horizons: [6],  // Default horizon for single model training
                                                          deterministicSeed: config.shuffleSeed ?? 42)
      logger.info(
        "🔧 Feature config: horizons=\(featureConfig.horizons), seed=\(featureConfig.deterministicSeed)"
      )

      let featureService = FeatureEngineeringService(
        configuration: featureConfig
      )
      logger.info("🔧 Generating features from \(ticks.count) ticks...")

      let allFeatures = try featureService.generateFeatures(from: ticks)
      let features = allFeatures.first ?? []  // Use first horizon for single model training

      timings.featureEngineeringTime = Date().timeIntervalSince(
        featureStart
      )

      await enhancedProgress?.pipelineDidUpdateStageProgress(.featureEngineering,
                                                             progress: 1.0)
      await enhancedProgress?.pipelineDidCompleteStage(
        .featureEngineering
      )
      await progress?.trainPrepDidProcessHorizon(6,
                                                 featureCount: features.count)  // Default horizon
      logger.info(
        "✅ Feature engineering completed: \(features.count) feature vectors generated in \(timings.featureEngineeringTime)s"
      )

      // Step 4: MLMultiArray Conversion
      logger.info("🔄 Starting MLMultiArray conversion stage...")
      await enhancedProgress?.pipelineDidStartStage(
        .mlMultiArrayConversion
      )
      await enhancedProgress?.pipelineDidUpdateStageProgress(.mlMultiArrayConversion,
                                                             progress: 0.0)

      // Convert features to MLMultiArray (this happens inside CoreMLTraining)
      await enhancedProgress?.pipelineDidUpdateStageProgress(.mlMultiArrayConversion,
                                                             progress: 1.0)
      await enhancedProgress?.pipelineDidCompleteStage(
        .mlMultiArrayConversion
      )
      logger.info("✅ MLMultiArray conversion completed")

      // Step 5: Core ML Training (Step 4 module)
      logger.info("🎯 Starting model training stage...")
      await enhancedProgress?.pipelineDidStartStage(.modelTraining)
      await enhancedProgress?.pipelineDidUpdateStageProgress(.modelTraining,
                                                             progress: 0.0)
      let trainingStart = Date()

      let trainer = CoreMLTraining(config: config, progressDelegate: nil)  // Progress handled by TrainPrepProgressDelegate
      logger.info(
        "🎯 Training model with \(features.count) features, config: \(String(describing: config))"
      )

      let model = try await trainer.trainModel(with: features)

      timings.trainingTime = Date().timeIntervalSince(trainingStart)

      await enhancedProgress?.pipelineDidUpdateStageProgress(.modelTraining,
                                                             progress: 1.0)
      await enhancedProgress?.pipelineDidCompleteStage(.modelTraining)
      logger.info(
        "✅ Model training completed successfully in \(timings.trainingTime)s"
      )

      // Step 6: Model Validation
      logger.info("📊 Starting model validation stage...")
      await enhancedProgress?.pipelineDidStartStage(.modelValidation)
      await enhancedProgress?.pipelineDidUpdateStageProgress(.modelValidation,
                                                             progress: 0.0)
      let validationStart2 = Date()

      logger.info("📊 Evaluating model on \(features.count) features...")
      let validationMetrics = try trainer.evaluate(model, on: features)

      timings.validationTime = Date().timeIntervalSince(validationStart2)

      // Check model performance gate
      let modelMetrics = ModelPerformanceMetrics(accuracy: validationMetrics.accuracy,
                                                 loss: validationMetrics.loss,
                                                 f1Score: validationMetrics.f1Score,
                                                 precision: validationMetrics.precision,
                                                 recall: validationMetrics.recall,
                                                 confusionMatrix: validationMetrics.confusionMatrix)

      logger.info(
        "📊 Model performance: accuracy=\(validationMetrics.accuracy), loss=\(validationMetrics.loss)"
      )
      logger.info("📊 Evaluating model performance gate...")
      let shouldDeploy =
        await enhancedProgress?.pipelineDidEvaluateModelPerformanceGate(
          modelMetrics
        ) ?? true
      logger.info(
        "📊 Model performance gate result: \(shouldDeploy ? "PASS" : "FAIL")"
      )

      guard shouldDeploy else {
        let error = CoreMLTrainingError.validationFailed(
          metrics: validationMetrics
        )
        logger.error(
          "❌ Model performance gate failed: \(error.localizedDescription)"
        )
        await enhancedProgress?.pipelineDidFailStage(.modelValidation,
                                                     error: error)
        throw error
      }

      await enhancedProgress?.pipelineDidUpdateStageProgress(.modelValidation,
                                                             progress: 1.0)
      await enhancedProgress?.pipelineDidCompleteStage(.modelValidation)
      logger.info(
        "✅ Model validation completed successfully in \(timings.validationTime)s"
      )

      // Step 7: Artifact Export
      logger.info("📦 Starting artifact export stage...")
      await enhancedProgress?.pipelineDidStartStage(.artifactExport)
      await enhancedProgress?.pipelineDidUpdateStageProgress(.artifactExport,
                                                             progress: 0.0)

      // Calculate total duration
      timings.totalDuration = Date().timeIntervalSince(startTime)

      // Generate comprehensive training report with statistical metrics
      logger.info(
        "📋 Generating training report with statistical metrics..."
      )
      let report = generateTrainingReport(timings: timings,
                                          dataQuality: validationResult.dataQualityMetrics,
                                          modelPerformance: validationMetrics,
                                          configuration: config,
                                          ticks: ticks,
                                          features: features,
                                          startTime: startTime,
                                          validationMetrics: validationMetrics,
                                          trainer: trainer,
                                          model: model)

      await enhancedProgress?.pipelineDidUpdateStageProgress(.artifactExport,
                                                             progress: 1.0)
      await enhancedProgress?.pipelineDidCompleteStage(.artifactExport)
      logger.info("✅ Artifact export completed")

      // Update pipeline metrics
      let pipelineMetrics = PipelineMetrics(stageDurations: [
        .dataLoading: timings.dataLoadingTime,
        .dataValidation: timings.dataValidationTime,
        .featureEngineering: timings.featureEngineeringTime,
        .mlMultiArrayConversion: 0.0,  // Minimal time
        .modelTraining: timings.trainingTime,
        .modelValidation: timings.validationTime,
        .artifactExport: 0.0,  // Minimal time
      ],
      recordCounts: [
        .dataLoading: ticks.count,
        .dataValidation: validationResult.totalRecords,
        .featureEngineering: features.count,
        .mlMultiArrayConversion: features.count,
        .modelTraining: features.count,
        .modelValidation: features.count,
        .artifactExport: 1,  // One model exported
      ])
      await enhancedProgress?.pipelineDidUpdateMetrics(pipelineMetrics)

      await progress?.trainPrepDidComplete()
      await enhancedProgress?.pipelineDidComplete([6: "trained_model"])  // Single horizon model
      logger.info(
        "✅ ML pipeline completed successfully in \(timings.totalDuration)s"
      )

      return (model, report)

    } catch {
      logger.error(
        "❌ ML pipeline failed at stage: \(error.localizedDescription)"
      )
      logger.error("❌ Error type: \(type(of: error))")
      if let coreMLError = error as? CoreMLTrainingError {
        logger.error("❌ CoreMLTrainingError details: \(coreMLError)")
      }
      await progress?.trainPrepDidFail(error)
      await enhancedProgress?.pipelineDidFail(error)
      logger.error("❌ ML pipeline failed: \(error.localizedDescription)")
      throw error
    }
  }
}

// MARK: - Private Helper Methods

private extension TrainPrepService {
  /// Parse NDJSON data from URL
  func parseNDJSON(from url: URL) async throws -> [ProbeTickRaw] {
    let data = try String(contentsOf: url, encoding: .utf8)
    var result = [ProbeTickRaw]()

    for (i, line) in data.split(separator: "\n").enumerated() {
      if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        continue
      }

      if let decoded = try? JSONDecoder.bridgeDecoder().decode(ProbeTickRaw.self,
                                                               from: Data(line.utf8))
      {
        result.append(decoded)
      } else {
        logger.warning(
          "Failed to parse line \(i + 1): Could not decode ProbeTickRaw"
        )
      }
    }

    return result
  }

  /// Generate comprehensive training report with statistical metrics
  func generateTrainingReport(timings: PipelineTimings,
                              dataQuality: DataQualityMetrics,
                              modelPerformance: CoreMLModelValidationResult,
                              configuration: CoreMLTrainingConfig,
                              ticks: [ProbeTickRaw],
                              features: [FeatureVector],
                              startTime: Date,
                              validationMetrics _: CoreMLModelValidationResult,
                              trainer: CoreMLTraining,
                              model: MLModel) -> TrainingReport
  {
    // Extract unique bridge IDs
    let bridgeIds = Set(ticks.map { $0.bridge_id })

    // Generate seeds for reproducibility
    let seeds = TrainingSeeds(featureEngineeringSeed: Int(configuration.shuffleSeed ?? 42),
                              trainingSeed: Int(configuration.shuffleSeed ?? 42),
                              validationSeed: Int(configuration.shuffleSeed ?? 42))

    // Define model shapes
    let shapes = ModelShapes(inputShape: configuration.inputShape,
                             outputShape: configuration.outputShape,
                             featureCount: FeatureVector.featureCount,
                             targetCount: targetDimension)

    // Generate metadata
    let metadata = TrainingMetadata(startTime: startTime,
                                    endTime: Date(),
                                    deviceInfo: ProcessInfo.processInfo.hostName,
                                    osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                                    appVersion: Bundle.main.infoDictionary?[
                                      "CFBundleShortVersionString"
                                    ] as? String ?? "Unknown",
                                    recordCount: ticks.count,
                                    bridgeCount: bridgeIds.count,
                                    horizons: [6]  // Default horizon for single model training
    )

    // Generate statistical metrics for Phase 3 enhancement using CoreMLTraining
    let statisticalMetrics = try? trainer.computeStatisticalMetrics(model,
                                                                    on: features,
                                                                    lossTrend: [],  // TODO: Capture loss trend during training
                                                                    accuracyTrend: []  // TODO: Capture accuracy trend during training
    )

    return TrainingReport(timings: timings,
                          dataQuality: dataQuality,
                          modelPerformance: modelPerformance,
                          configuration: configuration,
                          seeds: seeds,
                          shapes: shapes,
                          metadata: metadata,
                          statisticalMetrics: statisticalMetrics)
  }
}

// MARK: - Legacy Support (for backward compatibility)

/// Legacy configuration structure (deprecated - use CoreMLTrainingConfig)
public struct TrainPrepConfiguration {
  let inputPath: String
  let outputDirectory: String
  let trainingConfig: TrainingConfig
  let enableProgressReporting: Bool

  init(inputPath: String = "minutes_2025-01-27.ndjson",
       outputDirectory: String = FileManagerUtils.temporaryDirectory().path,
       trainingConfig: TrainingConfig = .production,
       enableProgressReporting: Bool = true)
  {
    self.inputPath = inputPath
    self.outputDirectory = outputDirectory
    self.trainingConfig = trainingConfig
    self.enableProgressReporting = enableProgressReporting
  }
}

/// Legacy process method (deprecated - use runPipeline)
public extension TrainPrepService {
  func process() async throws {
    // Convert legacy config to new config
    let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                      epochs: 100,
                                      learningRate: 0.001,
                                      batchSize: 32,
                                      useANE: true)

    let url = URL(fileURLWithPath: "minutes_2025-01-27.ndjson")
    _ = try await runPipeline(from: url, config: config)
  }
}

// MARK: - Convenience Functions

/// Legacy convenience function (deprecated - use TrainPrepService.runPipeline)
public func processTrainingData(inputPath: String,
                                outputDirectory _: String? = nil,
                                trainingConfig _: TrainingConfig = .production,
                                progressDelegate: TrainPrepProgressDelegate? = nil) async throws
{
  let config = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                    epochs: 100,
                                    learningRate: 0.001,
                                    batchSize: 32,
                                    useANE: true)

  let service = TrainPrepService()
  let url = URL(fileURLWithPath: inputPath)
  _ = try await service.runPipeline(from: url,
                                    config: config,
                                    progress: progressDelegate)
}

// MARK: - Test Support

/// Test progress delegate for integration testing
public class TestProgressDelegate: TrainPrepProgressDelegate {
  public func trainPrepDidStart() {}
  public func trainPrepDidLoadData(_: Int) {}
  public func trainPrepDidProcessHorizon(_: Int, featureCount _: Int) {}
  public func trainPrepDidSaveHorizon(_: Int, to _: String) {}
  public func trainPrepDidComplete() {}
  public func trainPrepDidFail(_: Error) {}
}
