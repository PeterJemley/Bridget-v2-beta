//
//  EnhancedPipelineUsage.swift
//  Bridget
//
//  ## Purpose
//  Example usage of the Enhanced ML Pipeline with all refinements
//  Demonstrates parallelization, retry mechanisms, checkpointing, and validation gates
//
//  ## Dependencies
//  EnhancedTrainPrepService, EnhancedPipelineConfig
//
//  ## Key Features Demonstrated
//  - Dynamic configuration loading from JSON
//  - Parallel processing with TaskGroup
//  - Retry mechanisms with exponential backoff
//  - Checkpointing for resumable pipelines
//  - Validation gates for data quality and model performance
//  - Comprehensive metrics and logging
//

import Foundation

// MARK: - Example Usage

/// Example of using the enhanced pipeline with all refinements
public class EnhancedPipelineExample {
  /// Run the enhanced pipeline with JSON configuration
  public static func runWithJSONConfig(configPath: String) async throws {
    print("🚀 Starting Enhanced ML Pipeline with JSON Configuration")

    // Load configuration from JSON file
    let config = try EnhancedPipelineConfig.load(from: configPath)
    print("✅ Configuration loaded from: \(configPath)")

    // Create progress delegate for monitoring
    let progressDelegate = await ExampleProgressDelegate()

    // Create and run the enhanced service
    let service = EnhancedTrainPrepService(configuration: config,
                                           progressDelegate: progressDelegate)

    try await service.execute()
    print("🎉 Enhanced pipeline completed successfully!")
  }

  /// Run the enhanced pipeline with programmatic configuration
  public static func runWithProgrammaticConfig() async throws {
    print("🚀 Starting Enhanced ML Pipeline with Programmatic Configuration")

    // Create configuration programmatically
    let config = EnhancedPipelineConfig(inputPath: "data/minutes_2025-01-27.ndjson",
                                        outputDirectory: "output",
                                        trainingConfig: .production,
                                        enableParallelization: true,
                                        maxConcurrentHorizons: 6,  // More aggressive parallelization
                                        batchSize: 2000,  // Larger batches for better performance
                                        maxRetryAttempts: 5,  // More retry attempts
                                        retryBackoffMultiplier: 1.5,  // Slower backoff
                                        enableCheckpointing: true,
                                        checkpointDirectory: "checkpoints",
                                        dataQualityThresholds: DataQualityThresholds(maxNaNRate: 0.03,  // Stricter data quality
                                                                                     minValidationRate: 0.98,
                                                                                     maxInvalidRecordRate: 0.01,
                                                                                     minDataVolume: 2000),
                                        modelPerformanceThresholds: ModelPerformanceThresholds(minAccuracy: 0.80,  // Higher performance requirements
                                                                                               maxLoss: 0.4,
                                                                                               minF1Score: 0.75),
                                        enableDetailedLogging: true,
                                        enableMetricsExport: true,
                                        metricsExportPath: "metrics/enhanced_pipeline_metrics.json",
                                        enableProgressReporting: true,
                                        memoryOptimizationLevel: .minimal  // Fastest processing
    )

    // Create progress delegate
    let progressDelegate = await ExampleProgressDelegate()

    // Create and run the enhanced service
    let service = EnhancedTrainPrepService(configuration: config,
                                           progressDelegate: progressDelegate)

    try await service.execute()
    print("🎉 Enhanced pipeline completed successfully!")
  }

  /// Run the enhanced pipeline with custom retry policies
  public static func runWithCustomRetryPolicies() async throws {
    print("🚀 Starting Enhanced ML Pipeline with Custom Retry Policies")

    // Create configuration with custom retry settings
    let config = EnhancedPipelineConfig(inputPath: "data/minutes_2025-01-27.ndjson",
                                        outputDirectory: "output",
                                        trainingConfig: .production,
                                        enableParallelization: true,
                                        maxConcurrentHorizons: 4,
                                        batchSize: 1000,
                                        maxRetryAttempts: 10,  // Many retry attempts
                                        retryBackoffMultiplier: 3.0,  // Aggressive backoff
                                        enableCheckpointing: true,
                                        checkpointDirectory: "checkpoints",
                                        dataQualityThresholds: .default,
                                        modelPerformanceThresholds: .default,
                                        enableDetailedLogging: true,
                                        enableMetricsExport: true,
                                        metricsExportPath: "metrics/custom_retry_metrics.json",
                                        enableProgressReporting: true,
                                        memoryOptimizationLevel: .balanced)

    // Create progress delegate
    let progressDelegate = await ExampleProgressDelegate()

    // Create and run the enhanced service
    let service = EnhancedTrainPrepService(configuration: config,
                                           progressDelegate: progressDelegate)

    try await service.execute()
    print("🎉 Enhanced pipeline with custom retry policies completed!")
  }

  /// Run the enhanced pipeline with memory optimization
  public static func runWithMemoryOptimization() async throws {
    print("🚀 Starting Enhanced ML Pipeline with Memory Optimization")

    // Create configuration optimized for memory usage
    let config = EnhancedPipelineConfig(inputPath: "data/minutes_2025-01-27.ndjson",
                                        outputDirectory: "output",
                                        trainingConfig: .production,
                                        enableParallelization: false,  // Disable parallelization to save memory
                                        maxConcurrentHorizons: 1,  // Single horizon processing
                                        batchSize: 500,  // Smaller batches
                                        maxRetryAttempts: 3,
                                        retryBackoffMultiplier: 2.0,
                                        enableCheckpointing: true,
                                        checkpointDirectory: "checkpoints",
                                        dataQualityThresholds: .default,
                                        modelPerformanceThresholds: .default,
                                        enableDetailedLogging: true,
                                        enableMetricsExport: true,
                                        metricsExportPath: "metrics/memory_optimized_metrics.json",
                                        enableProgressReporting: true,
                                        memoryOptimizationLevel: .aggressive  // Most memory-efficient
    )

    // Create progress delegate
    let progressDelegate = await ExampleProgressDelegate()

    // Create and run the enhanced service
    let service = EnhancedTrainPrepService(configuration: config,
                                           progressDelegate: progressDelegate)

    try await service.execute()
    print("🎉 Enhanced pipeline with memory optimization completed!")
  }
}

// MARK: - Example Progress Delegate

/// Example progress delegate that implements all enhanced pipeline callbacks
public class ExampleProgressDelegate: EnhancedPipelineProgressDelegate {
  public init() {}

  // MARK: - Stage Lifecycle

  public func pipelineDidStartStage(_ stage: PipelineStage) {
    print("🔄 Starting stage: \(stage.displayName)")
  }

  public func pipelineDidUpdateStageProgress(_ stage: PipelineStage, progress: Double) {
    let percentage = Int(progress * 100)
    print("📊 \(stage.displayName): \(percentage)% complete")
  }

  public func pipelineDidCompleteStage(_ stage: PipelineStage) {
    print("✅ Completed stage: \(stage.displayName)")
  }

  public func pipelineDidFailStage(_ stage: PipelineStage, error: Error) {
    print("❌ Stage failed: \(stage.displayName) - \(error.localizedDescription)")
  }

  // MARK: - Checkpointing

  public func pipelineDidCreateCheckpoint(_ stage: PipelineStage, at path: String) {
    print("💾 Created checkpoint for \(stage.displayName) at: \(path)")
  }

  public func pipelineDidResumeFromCheckpoint(_ stage: PipelineStage, at path: String) {
    print("🔄 Resumed from checkpoint for \(stage.displayName) at: \(path)")
  }

  // MARK: - Validation Gates

  public func pipelineDidEvaluateDataQualityGate(_ result: DataValidationResult) -> Bool {
    let passed = result.isValid && result.validationRate >= 0.95 && result.errors.count <= 5

    if passed {
      print("✅ Data quality gate passed: \(result.validRecordCount) valid records")
    } else {
      print("❌ Data quality gate failed: \(result.errors.joined(separator: ", "))")
    }

    return passed
  }

  public func pipelineDidEvaluateModelPerformanceGate(_ metrics: ModelPerformanceMetrics) -> Bool {
    let passed = metrics.accuracy >= 0.75 && metrics.loss <= 0.5 && metrics.f1Score >= 0.70

    if passed {
      print("✅ Model performance gate passed: accuracy \(String(format: "%.3f", metrics.accuracy))")
    } else {
      print(
        "❌ Model performance gate failed: accuracy \(String(format: "%.3f", metrics.accuracy)), loss \(String(format: "%.3f", metrics.loss))"
      )
    }

    return passed
  }

  // MARK: - Performance Metrics

  public func pipelineDidUpdateMetrics(_ metrics: PipelineMetrics) {
    print("📈 Pipeline metrics updated at \(metrics.timestamp)")

    // Log stage durations
    for (stage, duration) in metrics.stageDurations {
      print("   \(stage.displayName): \(String(format: "%.2f", duration))s")
    }

    // Log memory usage
    for (stage, memoryMB) in metrics.memoryUsage {
      print("   \(stage.displayName): \(memoryMB) MB")
    }
  }

  public func pipelineDidExportMetrics(to path: String) {
    print("📊 Metrics exported to: \(path)")
  }

  // MARK: - Overall Pipeline

  public func pipelineDidComplete(_ models: [Int: String]) {
    print("🎉 Pipeline completed successfully!")
    print("   Generated models: \(models.count)")

    for (horizon, path) in models {
      print("   Horizon \(horizon): \(path)")
    }
  }

  public func pipelineDidFail(_ error: Error) {
    print("💥 Pipeline failed: \(error.localizedDescription)")
  }
}

// MARK: - Main Function

/// Main function demonstrating different pipeline configurations
public enum EnhancedPipelineDemo {
  public static func main() async {
    print("🚀 Bridget Enhanced ML Pipeline Demo")
    print("=====================================")

    do {
      // Example 1: Run with JSON configuration
      if FileManagerUtils.fileExists(at: "config/enhanced_pipeline.json") {
        try await EnhancedPipelineExample.runWithJSONConfig(
          configPath: "config/enhanced_pipeline.json")
      }

      // Example 2: Run with programmatic configuration
      try await EnhancedPipelineExample.runWithProgrammaticConfig()

      // Example 3: Run with custom retry policies
      try await EnhancedPipelineExample.runWithCustomRetryPolicies()

      // Example 4: Run with memory optimization
      try await EnhancedPipelineExample.runWithMemoryOptimization()

      print("\n🎉 All enhanced pipeline examples completed successfully!")

    } catch {
      print("❌ Enhanced pipeline demo failed: \(error.localizedDescription)")
      exit(1)
    }
  }
}
