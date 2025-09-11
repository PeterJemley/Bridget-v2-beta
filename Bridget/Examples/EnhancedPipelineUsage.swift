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
import OSLog

#if canImport(BridgetCore)
    import BridgetCore
#endif
#if canImport(BridgetMLPipeline)
    import BridgetMLPipeline
#endif

// MARK: - Example Usage

private let pipelineLogger = Logger(
    subsystem: "com.peterjemley.Bridget",
    category: "EnhancedPipelineUsage"
)

/// Example of using the enhanced pipeline with all refinements
public class EnhancedPipelineExample {
    /// Run the enhanced pipeline with JSON configuration
    public static func runWithJSONConfig(configPath: String) async throws {
        pipelineLogger.info(
            "🚀 Starting Enhanced ML Pipeline with JSON Configuration"
        )

        // Load configuration from JSON file
        let config = try EnhancedPipelineConfig.load(from: configPath)
        pipelineLogger.info("✅ Configuration loaded from: \(configPath)")

        // Create delegate and service on the main actor (initializer is @MainActor)
        let service: EnhancedTrainPrepService = await MainActor.run {
            let progressDelegate = ExampleProgressDelegate()
            return EnhancedTrainPrepService(
                configuration: config,
                progressDelegate: progressDelegate
            )
        }

        try await service.execute()
        pipelineLogger.info("🎉 Enhanced pipeline completed successfully!")
    }

    /// Run the enhanced pipeline with programmatic configuration
    public static func runWithProgrammaticConfig() async throws {
        pipelineLogger.info(
            "🚀 Starting Enhanced ML Pipeline with Programmatic Configuration"
        )

        // Create configuration programmatically
        let config = EnhancedPipelineConfig(
            inputPath: "data/minutes_2025-01-27.ndjson",
            outputDirectory: "output",
            trainingConfig: .production,
            enableParallelization: true,
            maxConcurrentHorizons: 6,  // More aggressive parallelization
            batchSize: 2000,  // Larger batches for better performance
            maxRetryAttempts: 5,  // More retry attempts
            retryBackoffMultiplier: 1.5,  // Slower backoff
            enableCheckpointing: true,
            checkpointDirectory: "checkpoints",
            dataQualityThresholds: DataQualityThresholds(
                maxNaNRate: 0.03,  // Stricter data quality
                minValidationRate: 0.98,
                maxInvalidRecordRate: 0.01,
                minDataVolume: 2000
            ),
            modelPerformanceThresholds: ModelPerformanceThresholds(
                minAccuracy: 0.80,  // Higher performance requirements
                maxLoss: 0.4,
                minF1Score: 0.75
            ),
            enableDetailedLogging: true,
            enableMetricsExport: true,
            metricsExportPath: "metrics/enhanced_pipeline_metrics.json",
            enableProgressReporting: true,
            memoryOptimizationLevel: .minimal  // Fastest processing
        )

        // Create delegate and service on the main actor (initializer is @MainActor)
        let service: EnhancedTrainPrepService = await MainActor.run {
            let progressDelegate = ExampleProgressDelegate()
            return EnhancedTrainPrepService(
                configuration: config,
                progressDelegate: progressDelegate
            )
        }

        try await service.execute()
        pipelineLogger.info("🎉 Enhanced pipeline completed successfully!")
    }

    /// Run the enhanced pipeline with custom retry policies
    public static func runWithCustomRetryPolicies() async throws {
        pipelineLogger.info(
            "🚀 Starting Enhanced ML Pipeline with Custom Retry Policies"
        )

        // Create configuration with custom retry settings
        let config = EnhancedPipelineConfig(
            inputPath: "data/minutes_2025-01-27.ndjson",
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
            memoryOptimizationLevel: .balanced
        )

        // Create delegate and service on the main actor (initializer is @MainActor)
        let service: EnhancedTrainPrepService = await MainActor.run {
            let progressDelegate = ExampleProgressDelegate()
            return EnhancedTrainPrepService(
                configuration: config,
                progressDelegate: progressDelegate
            )
        }

        try await service.execute()
        pipelineLogger.info(
            "🎉 Enhanced pipeline with custom retry policies completed!"
        )
    }

    /// Run the enhanced pipeline with memory optimization
    public static func runWithMemoryOptimization() async throws {
        pipelineLogger.info(
            "🚀 Starting Enhanced ML Pipeline with Memory Optimization"
        )

        // Create configuration optimized for memory usage
        let config = EnhancedPipelineConfig(
            inputPath: "data/minutes_2025-01-27.ndjson",
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

        // Create delegate and service on the main actor (initializer is @MainActor)
        let service: EnhancedTrainPrepService = await MainActor.run {
            let progressDelegate = ExampleProgressDelegate()
            return EnhancedTrainPrepService(
                configuration: config,
                progressDelegate: progressDelegate
            )
        }

        try await service.execute()
        pipelineLogger.info(
            "🎉 Enhanced pipeline with memory optimization completed!"
        )
    }
}

// MARK: - Example Progress Delegate

/// Example progress delegate that implements all enhanced pipeline callbacks
public class ExampleProgressDelegate: EnhancedPipelineProgressDelegate {
    public init() {}

    // MARK: - Stage Lifecycle

    public func pipelineDidStartStage(_ stage: PipelineStage) {
        pipelineLogger.info("🔄 Starting stage: \(stage.displayName)")
    }

    public func pipelineDidUpdateStageProgress(
        _ stage: PipelineStage,
        progress: Double
    ) {
        let percentage = Int(progress * 100)
        pipelineLogger.info("📊 \(stage.displayName): \(percentage)% complete")
    }

    public func pipelineDidCompleteStage(_ stage: PipelineStage) {
        pipelineLogger.info("✅ Completed stage: \(stage.displayName)")
    }

    public func pipelineDidFailStage(_ stage: PipelineStage, error: Error) {
        pipelineLogger.error(
            "❌ Stage failed: \(stage.displayName) - \(error.localizedDescription)"
        )
    }

    // MARK: - Checkpointing

    public func pipelineDidCreateCheckpoint(
        _ stage: PipelineStage,
        at path: String
    ) {
        pipelineLogger.info(
            "💾 Created checkpoint for \(stage.displayName) at: \(path)"
        )
    }

    public func pipelineDidResumeFromCheckpoint(
        _ stage: PipelineStage,
        at path: String
    ) {
        pipelineLogger.info(
            "🔄 Resumed from checkpoint for \(stage.displayName) at: \(path)"
        )
    }

    // MARK: - Validation Gates

    public func pipelineDidEvaluateDataQualityGate(
        _ result: DataValidationResult
    ) -> Bool {
        let passed =
            result.isValid && result.validationRate >= 0.95
            && result.errors.count <= 5

        if passed {
            pipelineLogger.info(
                "✅ Data quality gate passed: \(result.validRecordCount) valid records"
            )
        } else {
            pipelineLogger.error(
                "❌ Data quality gate failed: \(result.errors.joined(separator: ", "))"
            )
        }

        return passed
    }

    public func pipelineDidEvaluateModelPerformanceGate(
        _ metrics: ModelPerformanceMetrics
    ) -> Bool {
        let passed =
            metrics.accuracy >= 0.75 && metrics.loss <= 0.5
            && metrics.f1Score >= 0.70

        if passed {
            pipelineLogger.info(
                "✅ Model performance gate passed: accuracy \(String(format: "%.3f", metrics.accuracy))"
            )
        } else {
            pipelineLogger.error(
                "❌ Model performance gate failed: accuracy \(String(format: "%.3f", metrics.accuracy)), loss \(String(format: "%.3f", metrics.loss))"
            )
        }

        return passed
    }

    // MARK: - Performance Metrics

    public func pipelineDidUpdateMetrics(_ metrics: PipelineMetrics) {
        pipelineLogger.info(
            "📈 Pipeline metrics updated at \(metrics.timestamp)"
        )

        // Log stage durations
        for (stage, duration) in metrics.stageDurations {
            pipelineLogger.debug(
                "   \(stage.displayName): \(String(format: "%.2f", duration))s"
            )
        }

        // Log memory usage
        for (stage, memoryMB) in metrics.memoryUsage {
            pipelineLogger.debug("   \(stage.displayName): \(memoryMB) MB")
        }
    }

    public func pipelineDidExportMetrics(to path: String) {
        pipelineLogger.info("📊 Metrics exported to: \(path)")
    }

    // MARK: - Overall Pipeline

    public func pipelineDidComplete(_ models: [Int: String]) {
        pipelineLogger.info("🎉 Pipeline completed successfully!")
        pipelineLogger.info("   Generated models: \(models.count)")

        for (horizon, path) in models {
            pipelineLogger.info("   Horizon \(horizon): \(path)")
        }
    }

    public func pipelineDidFail(_ error: Error) {
        pipelineLogger.error("💥 Pipeline failed: \(error.localizedDescription)")
    }
}

// MARK: - Main Function

/// Main function demonstrating different pipeline configurations
public enum EnhancedPipelineDemo {
    public static func main() async {
        pipelineLogger.info("🚀 Bridget Enhanced ML Pipeline Demo")
        pipelineLogger.info("=====================================")

        do {
            // Example 1: Run with JSON configuration
            if FileManagerUtils.fileExists(at: "config/enhanced_pipeline.json")
            {
                try await EnhancedPipelineExample.runWithJSONConfig(
                    configPath: "config/enhanced_pipeline.json"
                )
            }

            // Example 2: Run with programmatic configuration
            try await EnhancedPipelineExample.runWithProgrammaticConfig()

            // Example 3: Run with custom retry policies
            try await EnhancedPipelineExample.runWithCustomRetryPolicies()

            // Example 4: Run with memory optimization
            try await EnhancedPipelineExample.runWithMemoryOptimization()

            pipelineLogger.info(
                "🎉 All enhanced pipeline examples completed successfully!"
            )

        } catch {
            pipelineLogger.error(
                "❌ Enhanced pipeline demo failed: \(error.localizedDescription)"
            )
        }
    }
}
