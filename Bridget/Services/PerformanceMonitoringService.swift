//
//  PerformanceMonitoringService.swift
//  Bridget
//
//  ## Purpose
//  Performance monitoring and budget tracking for ML training pipeline
//  Ensures performance stays within defined budgets
//
//  ## Dependencies
//  Foundation framework for timing and memory measurement
//
//  ## Integration Points
//  Used by TrainPrepService to monitor performance
//  Provides performance metrics for parity validation
//
//  ## Key Features
//  Stage-by-stage timing measurement
//  Memory usage tracking
//  Performance budget validation
//  Performance report generation
//

import Foundation
import os.log

// MARK: - Performance Metrics

public struct PerformanceMetrics {
  public let parseTimeMs: Double
  public let featureEngineeringTimeMs: Double
  public let mlMultiArrayConversionTimeMs: Double
  public let trainingTimeMs: Double
  public let validationTimeMs: Double
  public let peakMemoryMB: Double
  public let totalTimeMs: Double
  
  public init(parseTimeMs: Double = 0,
              featureEngineeringTimeMs: Double = 0,
              mlMultiArrayConversionTimeMs: Double = 0,
              trainingTimeMs: Double = 0,
              validationTimeMs: Double = 0,
              peakMemoryMB: Double = 0) {
    self.parseTimeMs = parseTimeMs
    self.featureEngineeringTimeMs = featureEngineeringTimeMs
    self.mlMultiArrayConversionTimeMs = mlMultiArrayConversionTimeMs
    self.trainingTimeMs = trainingTimeMs
    self.validationTimeMs = validationTimeMs
    self.peakMemoryMB = peakMemoryMB
    self.totalTimeMs = parseTimeMs + featureEngineeringTimeMs + mlMultiArrayConversionTimeMs + trainingTimeMs + validationTimeMs
  }
}

// MARK: - Performance Budget

public struct PerformanceBudget {
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

// MARK: - Budget Validation Result

public struct BudgetValidationResult {
  public let isWithinBudget: Bool
  public let exceededStages: [String]
  public let performanceRating: String
  public let recommendations: [String]
  
  public init(isWithinBudget: Bool, exceededStages: [String], performanceRating: String, recommendations: [String]) {
    self.isWithinBudget = isWithinBudget
    self.exceededStages = exceededStages
    self.performanceRating = performanceRating
    self.recommendations = recommendations
  }
}

// MARK: - Main Service

public class PerformanceMonitoringService {
  private let logger = Logger(subsystem: "com.bridget.pipeline", category: "performance")
  private let budget: PerformanceBudget
  private var startTimes: [String: Date] = [:]
  private var metrics = PerformanceMetrics()
  
  public init(budget: PerformanceBudget = .production) {
    self.budget = budget
  }
  
  /// Start timing a stage
  /// - Parameter stage: Stage name to start timing
  public func startStage(_ stage: String) {
    startTimes[stage] = Date()
    logger.info("Started stage: \(stage)")
  }
  
  /// End timing a stage and record metrics
  /// - Parameter stage: Stage name to end timing
  public func endStage(_ stage: String) {
    guard let startTime = startTimes[stage] else {
      logger.warning("Attempted to end untracked stage: \(stage)")
      return
    }
    
    let duration = Date().timeIntervalSince(startTime) * 1000 // Convert to milliseconds
    logger.info("Completed stage: \(stage) in \(String(format: "%.2f", duration))ms")
    
    // Update metrics based on stage
    switch stage {
    case "parse":
      metrics = PerformanceMetrics(
        parseTimeMs: duration,
        featureEngineeringTimeMs: metrics.featureEngineeringTimeMs,
        mlMultiArrayConversionTimeMs: metrics.mlMultiArrayConversionTimeMs,
        trainingTimeMs: metrics.trainingTimeMs,
        validationTimeMs: metrics.validationTimeMs,
        peakMemoryMB: metrics.peakMemoryMB
      )
    case "featureEngineering":
      metrics = PerformanceMetrics(
        parseTimeMs: metrics.parseTimeMs,
        featureEngineeringTimeMs: duration,
        mlMultiArrayConversionTimeMs: metrics.mlMultiArrayConversionTimeMs,
        trainingTimeMs: metrics.trainingTimeMs,
        validationTimeMs: metrics.validationTimeMs,
        peakMemoryMB: metrics.peakMemoryMB
      )
    case "mlMultiArrayConversion":
      metrics = PerformanceMetrics(
        parseTimeMs: metrics.parseTimeMs,
        featureEngineeringTimeMs: metrics.featureEngineeringTimeMs,
        mlMultiArrayConversionTimeMs: duration,
        trainingTimeMs: metrics.trainingTimeMs,
        validationTimeMs: metrics.validationTimeMs,
        peakMemoryMB: metrics.peakMemoryMB
      )
    case "training":
      metrics = PerformanceMetrics(
        parseTimeMs: metrics.parseTimeMs,
        featureEngineeringTimeMs: metrics.featureEngineeringTimeMs,
        mlMultiArrayConversionTimeMs: metrics.mlMultiArrayConversionTimeMs,
        trainingTimeMs: duration,
        validationTimeMs: metrics.validationTimeMs,
        peakMemoryMB: metrics.peakMemoryMB
      )
    case "validation":
      metrics = PerformanceMetrics(
        parseTimeMs: metrics.parseTimeMs,
        featureEngineeringTimeMs: metrics.featureEngineeringTimeMs,
        mlMultiArrayConversionTimeMs: metrics.mlMultiArrayConversionTimeMs,
        trainingTimeMs: metrics.trainingTimeMs,
        validationTimeMs: duration,
        peakMemoryMB: metrics.peakMemoryMB
      )
    default:
      logger.warning("Unknown stage: \(stage)")
    }
    
    startTimes.removeValue(forKey: stage)
  }
  
  /// Record memory usage
  /// - Parameter memoryMB: Memory usage in MB
  public func recordMemoryUsage(_ memoryMB: Double) {
    if memoryMB > metrics.peakMemoryMB {
      metrics = PerformanceMetrics(
        parseTimeMs: metrics.parseTimeMs,
        featureEngineeringTimeMs: metrics.featureEngineeringTimeMs,
        mlMultiArrayConversionTimeMs: metrics.mlMultiArrayConversionTimeMs,
        trainingTimeMs: metrics.trainingTimeMs,
        validationTimeMs: metrics.validationTimeMs,
        peakMemoryMB: memoryMB
      )
    }
  }
  
  /// Get current performance metrics
  /// - Returns: Current performance metrics
  public func getCurrentMetrics() -> PerformanceMetrics {
    return metrics
  }
  
  /// Validate performance against budget
  /// - Returns: Budget validation result
  public func validateBudget() -> BudgetValidationResult {
    var exceededStages: [String] = []
    var recommendations: [String] = []
    
    if metrics.parseTimeMs > budget.parseTimeMs {
      exceededStages.append("Parse")
      recommendations.append("Optimize NDJSON parsing with streaming or batch processing")
    }
    
    if metrics.featureEngineeringTimeMs > budget.featureEngineeringTimeMs {
      exceededStages.append("Feature Engineering")
      recommendations.append("Consider parallel processing or caching intermediate results")
    }
    
    if metrics.mlMultiArrayConversionTimeMs > budget.mlMultiArrayConversionTimeMs {
      exceededStages.append("MLMultiArray Conversion")
      recommendations.append("Pre-allocate arrays or use batch conversion")
    }
    
    if metrics.trainingTimeMs > budget.trainingTimeMs {
      exceededStages.append("Training")
      recommendations.append("Reduce batch size, use ANE, or implement early stopping")
    }
    
    if metrics.validationTimeMs > budget.validationTimeMs {
      exceededStages.append("Validation")
      recommendations.append("Optimize validation data loading or use sampling")
    }
    
    if metrics.peakMemoryMB > budget.peakMemoryMB {
      exceededStages.append("Memory")
      recommendations.append("Implement memory pooling or reduce batch sizes")
    }
    
    let isWithinBudget = exceededStages.isEmpty
    let performanceRating = isWithinBudget ? "Excellent" : "Needs Optimization"
    
    return BudgetValidationResult(
      isWithinBudget: isWithinBudget,
      exceededStages: exceededStages,
      performanceRating: performanceRating,
      recommendations: recommendations
    )
  }
  
  /// Generate performance report
  /// - Returns: Formatted performance report
  public func generateReport() -> String {
    let validation = validateBudget()
    
    let report = """
    Performance Report
    =================
    
    Stage Timings:
    - Parse: \(String(format: "%.2f", metrics.parseTimeMs))ms (Budget: \(String(format: "%.2f", budget.parseTimeMs))ms)
    - Feature Engineering: \(String(format: "%.2f", metrics.featureEngineeringTimeMs))ms (Budget: \(String(format: "%.2f", budget.featureEngineeringTimeMs))ms)
    - MLMultiArray Conversion: \(String(format: "%.2f", metrics.mlMultiArrayConversionTimeMs))ms (Budget: \(String(format: "%.2f", budget.mlMultiArrayConversionTimeMs))ms)
    - Training: \(String(format: "%.2f", metrics.trainingTimeMs))ms (Budget: \(String(format: "%.2f", budget.trainingTimeMs))ms)
    - Validation: \(String(format: "%.2f", metrics.validationTimeMs))ms (Budget: \(String(format: "%.2f", budget.validationTimeMs))ms)
    
    Memory Usage:
    - Peak Memory: \(String(format: "%.2f", metrics.peakMemoryMB))MB (Budget: \(String(format: "%.2f", budget.peakMemoryMB))MB)
    
    Total Time: \(String(format: "%.2f", metrics.totalTimeMs))ms
    
    Budget Validation: \(validation.isWithinBudget ? "✅ PASS" : "❌ FAIL")
    Performance Rating: \(validation.performanceRating)
    
    \(validation.exceededStages.isEmpty ? "All stages within budget" : "Exceeded stages: \(validation.exceededStages.joined(separator: ", "))")
    
    \(validation.recommendations.isEmpty ? "" : "Recommendations:\n" + validation.recommendations.map { "- \($0)" }.joined(separator: "\n"))
    """
    
    return report
  }
}

// MARK: - Convenience Functions

public func createPerformanceMonitor(budget: PerformanceBudget = .production) -> PerformanceMonitoringService {
  return PerformanceMonitoringService(budget: budget)
}

public func measurePerformance<T>(_ stage: String, monitor: PerformanceMonitoringService, operation: () throws -> T) rethrows -> T {
  monitor.startStage(stage)
  defer { monitor.endStage(stage) }
  return try operation()
}

public func measurePerformanceAsync<T>(_ stage: String, monitor: PerformanceMonitoringService, operation: () async throws -> T) async rethrows -> T {
  monitor.startStage(stage)
  defer { monitor.endStage(stage) }
  return try await operation()
}
