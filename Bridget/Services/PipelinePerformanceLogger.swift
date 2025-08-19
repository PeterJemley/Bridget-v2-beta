//
//  PipelinePerformanceLogger.swift
//  Bridget
//
//  Purpose: Performance logging and metrics collection for ML pipeline baseline measurement
//

import Foundation
import OSLog
import MetricKit

/// Performance logger for ML pipeline operations to establish baseline metrics.
///
/// This service captures detailed performance metrics including wall-clock times,
/// memory usage, and pipeline step timings. It's designed for baseline measurement
/// before module extraction to ensure parity after refactoring.
///
/// ## Overview
///
/// The logger tracks:
/// - **Timing**: Wall-clock time for each pipeline step
/// - **Memory**: Peak memory usage and memory efficiency
/// - **Performance**: Records per second, validation counts
/// - **Artifacts**: File sizes, record counts, data quality metrics
///
/// ## Key Features
///
/// - **Step-by-step timing**: Granular timing for each pipeline operation
/// - **Memory profiling**: Peak memory usage and efficiency metrics
/// - **Performance metrics**: Processing rates and throughput
/// - **Artifact tracking**: File sizes, record counts, validation results
/// - **Baseline comparison**: Tools to compare before/after metrics
///
/// ## Usage
///
/// ```swift
/// let logger = PipelinePerformanceLogger()
/// logger.startPipeline()
///
/// logger.startStep("API Fetch")
/// // ... perform API fetch ...
/// logger.endStep("API Fetch")
///
/// logger.startStep("Data Processing")
/// // ... process data ...
/// logger.endStep("Data Processing")
///
/// logger.endPipeline()
/// logger.generateReport()
/// ```
///
/// ## Integration Points
///
/// - **OSLog**: For structured logging and performance tracking
/// - **MetricKit**: For system-level performance metrics
/// - **File System**: For saving detailed performance reports
/// - **BridgeDataExporter**: For export performance metrics
final class PipelinePerformanceLogger: NSObject {
  static let shared = PipelinePerformanceLogger()
  
  private let logger = Logger(subsystem: "Bridget", category: "PipelinePerformance")
  private let metricManager = MXMetricManager.shared
  
  // MARK: - Performance Tracking
  
  private var pipelineStartTime: Date?
  private var stepTimings: [String: TimeInterval] = [:]
  private var stepStartTimes: [String: Date] = [:]
  private var memoryBaseline: Int64 = 0
  private var memoryPeak: Int64 = 0
  
  // MARK: - Artifact Tracking
  
  private var inputRecordCount: Int = 0
  private var outputRecordCount: Int = 0
  private var validationFailures: Int = 0
  private var correctedRows: Int = 0
  private var outputFileSize: Int64 = 0
  
  private override init() {
    super.init()
    self.setupMetricKit()
  }
  
  // MARK: - Pipeline Lifecycle
  
  /// Starts timing the overall pipeline execution.
  func startPipeline() {
    self.pipelineStartTime = Date()
    self.memoryBaseline = self.getCurrentMemoryUsage()
    self.memoryPeak = self.memoryBaseline
    
    self.logger.info("🚀 Pipeline execution started")
    self.logger.info("📊 Memory baseline: \(self.formatBytes(self.memoryBaseline))")
  }
  
  /// Ends timing the overall pipeline execution.
  func endPipeline() {
    guard let startTime = self.pipelineStartTime else {
      self.logger.error("Pipeline end called without start")
      return
    }
    
    let totalTime = Date().timeIntervalSince(startTime)
    self.memoryPeak = max(self.memoryPeak, self.getCurrentMemoryUsage())
    let finalMemory = self.getCurrentMemoryUsage()
    
    self.logger.info("✅ Pipeline execution completed")
    self.logger.info("⏱️ Total execution time: \(String(format: "%.3f", totalTime))s")
    self.logger.info("📊 Memory peak: \(self.formatBytes(self.memoryPeak))")
    self.logger.info("📊 Final memory: \(self.formatBytes(finalMemory))")
    
    self.generateReport()
  }
  
  // MARK: - Step Timing
  
  /// Starts timing a specific pipeline step.
  /// - Parameter stepName: Name of the step to time
  func startStep(_ stepName: String) {
    self.stepStartTimes[stepName] = Date()
    self.logger.info("▶️ Step started: \(stepName)")
  }
  
  /// Ends timing a specific pipeline step.
  /// - Parameter stepName: Name of the step to time
  func endStep(_ stepName: String) {
    guard let startTime = self.stepStartTimes[stepName] else {
      self.logger.error("Step end called without start: \(stepName)")
      return
    }
    
    let duration = Date().timeIntervalSince(startTime)
    self.stepTimings[stepName] = duration
    
    self.logger.info("⏹️ Step completed: \(stepName) (\(String(format: "%.3f", duration))s)")
  }
  
  // MARK: - Metrics Collection
  
  /// Records input data metrics.
  /// - Parameter recordCount: Number of input records
  func recordInputMetrics(recordCount: Int) {
    self.inputRecordCount = recordCount
    self.logger.info("📥 Input records: \(recordCount)")
  }
  
  /// Records output data metrics.
  /// - Parameter recordCount: Number of output records
  func recordOutputMetrics(recordCount: Int) {
    self.outputRecordCount = recordCount
    self.logger.info("📤 Output records: \(recordCount)")
  }
  
  /// Records validation metrics.
  /// - Parameters:
  ///   - failures: Number of validation failures
  ///   - corrections: Number of rows that required correction
  func recordValidationMetrics(failures: Int, corrections: Int) {
    self.validationFailures = failures
    self.correctedRows = corrections
    self.logger.info("✅ Validation: \(failures) failures, \(corrections) corrections")
  }
  
  /// Records file output metrics.
  /// - Parameter fileSize: Size of output file in bytes
  func recordFileMetrics(fileSize: Int64) {
    self.outputFileSize = fileSize
    self.logger.info("💾 Output file size: \(self.formatBytes(fileSize))")
  }
  
  /// Records memory usage at current point.
  func recordMemoryCheckpoint() {
    let currentMemory = self.getCurrentMemoryUsage()
    self.memoryPeak = max(self.memoryPeak, currentMemory)
    self.logger.info("📊 Memory checkpoint: \(self.formatBytes(currentMemory))")
  }
  
  // MARK: - Report Generation
  
  /// Generates a comprehensive performance report.
  func generateReport() {
    guard let startTime = self.pipelineStartTime else { return }
    
    let totalTime = Date().timeIntervalSince(startTime)
    let report = self.generateReportText(totalTime: totalTime)
    
    // Save report to file
    self.saveReport(report)
    
    // Log summary
    self.logger.info("📊 Performance report generated")
    self.logger.info("📈 Processing rate: \(String(format: "%.1f", Double(self.outputRecordCount) / totalTime)) records/sec")
    self.logger.info("💾 Memory efficiency: \(String(format: "%.1f", Double(self.outputRecordCount) / Double(self.memoryPeak))) records/MB")
  }
  
  private func generateReportText(totalTime: TimeInterval) -> String {
    var report = """
    # Pipeline Performance Report
    Generated: \(Date())
    
    ## Execution Summary
    - Total Time: \(String(format: "%.3f", totalTime))s
    - Input Records: \(self.inputRecordCount)
    - Output Records: \(self.outputRecordCount)
    - Processing Rate: \(String(format: "%.1f", Double(self.outputRecordCount) / totalTime)) records/sec
    
    ## Memory Usage
    - Baseline: \(self.formatBytes(self.memoryBaseline))
    - Peak: \(self.formatBytes(self.memoryPeak))
    - Final: \(self.formatBytes(self.getCurrentMemoryUsage()))
    - Efficiency: \(String(format: "%.1f", Double(self.outputRecordCount) / Double(self.memoryPeak))) records/MB
    
    ## Step-by-Step Timings
    """
    
    for (stepName, duration) in self.stepTimings.sorted(by: { $0.value > $1.value }) {
      let percentage = (duration / totalTime) * 100
      report += "\n- \(stepName): \(String(format: "%.3f", duration))s (\(String(format: "%.1f", percentage))%)"
    }
    
    report += """
    
    ## Data Quality
    - Validation Failures: \(self.validationFailures)
    - Corrected Rows: \(self.correctedRows)
    - Success Rate: \(String(format: "%.1f", Double(self.outputRecordCount) / Double(self.inputRecordCount) * 100))%
    
    ## Output Artifacts
    - File Size: \(self.formatBytes(self.outputFileSize))
    - Records per MB: \(String(format: "%.1f", Double(self.outputFileSize) / Double(self.outputRecordCount)))
    
    ## Performance Analysis
    - Bottleneck Step: \(self.stepTimings.max(by: { $0.value < $1.value })?.key ?? "Unknown")
    - Memory Pressure: \(self.memoryPeak > self.memoryBaseline * 2 ? "High" : "Normal")
    - Efficiency Rating: \(self.getEfficiencyRating(totalTime: totalTime, recordCount: self.outputRecordCount))
    """
    
    return report
  }
  
  private func saveReport(_ report: String) {
    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let reportURL = documentsPath.appendingPathComponent("pipeline_performance_\(Date().timeIntervalSince1970).md")
    
    do {
      try report.write(to: reportURL, atomically: true, encoding: .utf8)
      self.logger.info("📄 Performance report saved to: \(reportURL.path)")
    } catch {
      self.logger.error("Failed to save performance report: \(error.localizedDescription)")
    }
  }
  
  // MARK: - Utility Methods
  
  private func getCurrentMemoryUsage() -> Int64 {
    var info = mach_task_basic_info()
    var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
    
    let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
      $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
        task_info(mach_task_self_,
                 task_flavor_t(MACH_TASK_BASIC_INFO),
                 $0,
                 &count)
      }
    }
    
    if kerr == KERN_SUCCESS {
      return Int64(info.resident_size)
    } else {
      self.logger.error("Failed to get memory usage: \(kerr)")
      return 0
    }
  }
  
  private func formatBytes(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useMB, .useKB]
    formatter.countStyle = .memory
    return formatter.string(fromByteCount: bytes)
  }
  
  private func getEfficiencyRating(totalTime: TimeInterval, recordCount: Int) -> String {
    let recordsPerSecond = Double(recordCount) / totalTime
    
    switch recordsPerSecond {
    case 1000...: return "Excellent"
    case 500..<1000: return "Good"
    case 100..<500: return "Fair"
    default: return "Poor"
    }
  }
  
  private func setupMetricKit() {
    self.metricManager.add(self)
  }
}

// MARK: - MetricKit Integration

extension PipelinePerformanceLogger: MXMetricManagerSubscriber {
  func didReceive(_ payloads: [MXMetricPayload]) {
    for _ in payloads {
      self.logger.info("📊 MetricKit payload received")
    }
  }
}

// MARK: - Convenience Extensions

extension PipelinePerformanceLogger {
  /// Convenience method to time a block of code.
  /// - Parameters:
  ///   - stepName: Name of the step
  ///   - operation: Block of code to time
  /// - Returns: Result of the operation
  func timeStep<T>(_ stepName: String, operation: () throws -> T) rethrows -> T {
    self.startStep(stepName)
    defer { self.endStep(stepName) }
    return try operation()
  }
  
  /// Convenience method to time an async block of code.
  /// - Parameters:
  ///   - stepName: Name of the step
  ///   - operation: Async block of code to time
  /// - Returns: Result of the operation
  func timeStep<T>(_ stepName: String, operation: () async throws -> T) async rethrows -> T {
    self.startStep(stepName)
    defer { self.endStep(stepName) }
    return try await operation()
  }
}

