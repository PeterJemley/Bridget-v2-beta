//
//  PipelineParityValidator.swift
//  Bridget
//
//  Purpose: Validates pipeline output parity after module extraction to ensure no regressions
//  Dependencies: PipelinePerformanceLogger, baseline metrics, golden samples
//  Integration Points:
//    - Called after each module extraction to validate outputs
//    - Compares before/after results using golden samples
//    - Triggers loop-back to problematic module if parity fails
//    - Provides detailed regression analysis for debugging

import Foundation
import MetricKit
import OSLog

/// Configuration for parity validation tolerances and behavior
struct ParityConfig: Codable {
  /// Whether shape validation should be strict (no field changes allowed)
  let shapeStrict: Bool

  /// Percentage tolerance for count validation (0.0 = exact match)
  let countTolerancePct: Double

  /// Percentage tolerance for range validation (0.0 = exact match)
  let rangeTolerancePct: Double

  /// Percentage tolerance for performance validation (0.0 = exact match)
  let perfTolerancePct: Double

  /// Whether schema validation should be strict (no field changes allowed)
  let schemaStrict: Bool

  /// Epsilon value for avoiding division by zero in relative calculations
  let epsilon: Double

  /// Default configuration with conservative tolerances
  static let `default` = ParityConfig(shapeStrict: true,
                                      countTolerancePct: 0.0,  // Exact match required
                                      rangeTolerancePct: 0.05, // 5% tolerance
                                      perfTolerancePct: 0.10,  // 10% tolerance
                                      schemaStrict: true,
                                      epsilon: 1e-10)

  /// Relaxed configuration for development/testing
  static let relaxed = ParityConfig(shapeStrict: false,
                                    countTolerancePct: 0.02, // 2% tolerance
                                    rangeTolerancePct: 0.10, // 10% tolerance
                                    perfTolerancePct: 0.20,  // 20% tolerance
                                    schemaStrict: false,
                                    epsilon: 1e-10)
}

/// Represents a specific module that could be affected by changes
enum Module: String, CaseIterable, Codable {
  case featureEngineering = "FeatureEngineering"
  case dataValidation = "DataValidation"
  case coreMLTraining = "CoreMLTraining"
  case orchestrator = "Orchestrator"
  case schema = "Schema"
  case bridgeDataProcessor = "BridgeDataProcessor"
  case bridgeDataExporter = "BridgeDataExporter"
  case bridgeDataService = "BridgeDataService"
  case mlPipelineBackgroundManager = "MLPipelineBackgroundManager"

  var description: String {
    switch self {
    case .featureEngineering: return "Feature engineering and data transformation"
    case .dataValidation: return "Data validation and business rules"
    case .coreMLTraining: return "Core ML model training and inference"
    case .orchestrator: return "Pipeline orchestration and coordination"
    case .schema: return "Data schema and type definitions"
    case .bridgeDataProcessor: return "Bridge data processing and validation"
    case .bridgeDataExporter: return "Bridge data export and formatting"
    case .bridgeDataService: return "Bridge data service and API integration"
    case .mlPipelineBackgroundManager: return "ML pipeline background management"
    }
  }
}

/// Validates pipeline output parity after module extraction to ensure no regressions.
///
/// This service is critical for the dependency/recursion approach where outputs must remain
/// identical after each module extraction. If any changes are detected in shapes, counts,
/// or ranges, it triggers a loop-back to the module that just changed.
///
/// ## Overview
///
/// The validator performs comprehensive parity checks:
/// - **Shape Validation**: Output structure and schema consistency
/// - **Count Validation**: Record counts and distribution patterns
/// - **Range Validation**: Data value ranges and statistical distributions
/// - **Performance Validation**: Timing and memory usage consistency
///
/// ## Usage
///
/// ```swift
/// let validator = PipelineParityValidator(
///   logger: Logger(subsystem: "com.bridget.parity", category: "validation"),
///   config: ParityConfig.default
/// )
/// let result = try await validator.validateParity(
///   baseline: baselineMetrics,
///   current: currentOutput,
///   sample: goldenSample
/// )
///
/// if !result.isParity {
///   // Loop back to the module that just changed
///   print("Parity failed: \(result.failureReason)")
///   print("Affected module: \(result.affectedModule)")
/// }
/// ```
///
/// ## Topics
/// - Parity Validation: `validateParity(baseline:current:sample:)`
/// - Regression Detection: `detectRegressions(baseline:current:)`
/// - Module Impact Analysis: `analyzeModuleImpact(changes:)`
/// - Loop-back Guidance: `getLoopbackGuidance(failure:)`
class PipelineParityValidator {
  private let logger: Logger
  private let config: ParityConfig

  // MARK: - Parity Validation Result

  /// Result of a parity validation check
  struct ParityValidationResult: Codable {
    /// Whether the outputs maintain parity with baseline
    let isParity: Bool

    /// Detailed reason for parity failure (if any)
    let failureReason: String?

    /// Module that likely caused the parity failure
    let affectedModule: Module?

    /// Specific changes detected
    let detectedChanges: [OutputChange]

    /// Confidence level of the analysis (0.0 to 1.0)
    let confidence: Double

    /// Recommendations for loop-back
    let loopbackGuidance: String?

    /// Schema hashes for comparison
    let schemaHashBaseline: String
    let schemaHashCurrent: String

    /// Performance timings for comparison
    let timingsBaseline: [String: TimeInterval]
    let timingsCurrent: [String: TimeInterval]

    /// Memory usage for comparison
    let memoryBaseline: MemoryMetrics
    let memoryCurrent: MemoryMetrics

    /// Whether deterministic seed was used
    let deterministicSeedUsed: Bool

    /// Ranked list of likely affected modules
    let likelyModules: [Module]
  }

  /// Represents a specific change detected in outputs
  struct OutputChange: Codable {
    /// Type of change detected
    let changeType: ChangeType

    /// Field or metric affected
    let affectedField: String

    /// Baseline value
    let baselineValue: String

    /// Current value
    let currentValue: String

    /// Severity of the change
    let severity: ChangeSeverity

    /// Likely cause or module
    let likelyCause: String?

    /// Additional metadata for detailed analysis
    let metadata: [String: String]
  }

  /// Types of changes that can be detected
  enum ChangeType: String, CaseIterable, Codable {
    case shape = "Shape"
    case count = "Count"
    case range = "Range"
    case performance = "Performance"
    case schema = "Schema"
    case validation = "Validation"
  }

  /// Severity levels for detected changes
  enum ChangeSeverity: String, CaseIterable, Codable {
    case critical = "Critical"
    case major = "Major"
    case minor = "Minor"
    case informational = "Informational"
  }

  // MARK: - Initializer

  init(logger: Logger = Logger(subsystem: "com.bridget.parity", category: "validation"),
       config: ParityConfig = .default)
  {
    self.logger = logger
    self.config = config
  }

  // MARK: - Main Parity Validation

  /// Validates that current pipeline outputs maintain parity with baseline
  ///
  /// This is the core method that implements the dependency/recursion requirement.
  /// If outputs change in shapes, counts, or ranges, it provides guidance for
  /// looping back to the problematic module.
  ///
  /// - Parameters:
  ///   - baseline: Baseline metrics and outputs from before module extraction
  ///   - current: Current pipeline outputs after module extraction
  ///   - sample: Golden sample data used for validation
  /// - Returns: Parity validation result with detailed analysis
  /// - Throws: Validation errors if comparison fails
  func validateParity(baseline: BaselineMetrics,
                      current: CurrentOutput,
                      sample: GoldenSample) async throws -> ParityValidationResult
  {
    logger.info("🔍 Starting parity validation for sample: \(sample.name)")

    var detectedChanges: [OutputChange] = []
    var failureReason: String?
    var affectedModule: Module?

    // 1. Shape Validation - Check output structure consistency
    let shapeChanges = validateShapeParity(baseline: baseline, current: current)
    detectedChanges.append(contentsOf: shapeChanges)

    // 2. Count Validation - Check record counts and distributions
    let countChanges = validateCountParity(baseline: baseline, current: current, sample: sample)
    detectedChanges.append(contentsOf: countChanges)

    // 3. Range Validation - Check data value ranges and distributions
    let rangeChanges = validateRangeParity(baseline: baseline, current: current, sample: sample)
    detectedChanges.append(contentsOf: rangeChanges)

    // 4. Performance Validation - Check timing and memory consistency
    let performanceChanges = validatePerformanceParity(baseline: baseline, current: current)
    detectedChanges.append(contentsOf: performanceChanges)

    // 5. Schema Validation - Check data schema consistency
    let schemaChanges = validateSchemaParity(baseline: baseline, current: current)
    detectedChanges.append(contentsOf: schemaChanges)

    // Determine if parity is maintained
    let isParity = detectedChanges.allSatisfy { $0.severity == .informational }

    // Analyze which module likely caused the changes
    if !isParity {
      let moduleAnalysis = analyzeModuleImpact(changes: detectedChanges)
      affectedModule = moduleAnalysis.primaryModule
      failureReason = generateFailureReason(changes: detectedChanges)
    }

    // Calculate confidence level
    let confidence = calculateConfidence(changes: detectedChanges)

    // Generate loop-back guidance
    let loopbackGuidance = getLoopbackGuidance(failure: failureReason,
                                               affectedModule: affectedModule,
                                               changes: detectedChanges)

    // Get ranked list of likely modules
    let likelyModules = getRankedLikelyModules(changes: detectedChanges)

    let result = ParityValidationResult(isParity: isParity,
                                        failureReason: failureReason,
                                        affectedModule: affectedModule,
                                        detectedChanges: detectedChanges,
                                        confidence: confidence,
                                        loopbackGuidance: loopbackGuidance,
                                        schemaHashBaseline: baseline.schemaHash,
                                        schemaHashCurrent: current.schemaHash,
                                        timingsBaseline: baseline.stageTimings,
                                        timingsCurrent: current.stageTimings,
                                        memoryBaseline: baseline.memoryMetrics,
                                        memoryCurrent: current.memoryMetrics,
                                        deterministicSeedUsed: baseline.deterministicSeedUsed,
                                        likelyModules: likelyModules)

    // Log the results
    if isParity {
      logger.info("✅ Parity validation passed - outputs maintain consistency")
    } else {
      logger.error("❌ Parity validation failed - outputs have changed")
      logger.error("Affected module: \(affectedModule?.rawValue ?? "Unknown")")
      logger.error("Failure reason: \(failureReason ?? "Unknown")")
    }

    return result
  }

  // MARK: - Individual Validation Methods

  /// Validates shape parity (output structure consistency)
  private func validateShapeParity(baseline: BaselineMetrics, current: CurrentOutput) -> [OutputChange] {
    var changes: [OutputChange] = []

    // Check if output structure has changed
    if baseline.outputStructure != current.outputStructure {
      changes.append(OutputChange(changeType: .shape,
                                  affectedField: "output_structure",
                                  baselineValue: baseline.outputStructure,
                                  currentValue: current.outputStructure,
                                  severity: .critical,
                                  likelyCause: "Data processing pipeline changes",
                                  metadata: [:]))
    }

    // Check if field counts have changed
    if baseline.fieldCount != current.fieldCount {
      changes.append(OutputChange(changeType: .shape,
                                  affectedField: "field_count",
                                  baselineValue: "\(baseline.fieldCount)",
                                  currentValue: "\(current.fieldCount)",
                                  severity: config.shapeStrict ? .critical : .major,
                                  likelyCause: "Schema modifications or data transformation changes",
                                  metadata: [
                                    "baseline_fields": "\(baseline.fieldCount)",
                                    "current_fields": "\(current.fieldCount)",
                                    "field_difference": "\(current.fieldCount - baseline.fieldCount)",
                                  ]))
    }

    return changes
  }

  /// Validates count parity (record counts and distributions)
  private func validateCountParity(baseline: BaselineMetrics, current: CurrentOutput, sample: GoldenSample) -> [OutputChange] {
    var changes: [OutputChange] = []

    // Check total record count
    let expectedCount = sample.expectedRecordCount
    let countDifference = abs(current.totalRecords - expectedCount)
    let countTolerance = Int(Double(expectedCount) * config.countTolerancePct)

    if countDifference > countTolerance {
      changes.append(OutputChange(changeType: .count,
                                  affectedField: "total_records",
                                  baselineValue: "\(expectedCount)",
                                  currentValue: "\(current.totalRecords)",
                                  severity: countDifference > expectedCount / 10 ? .critical : .major,
                                  likelyCause: "Data ingestion or processing pipeline changes",
                                  metadata: [
                                    "expected_count": "\(expectedCount)",
                                    "actual_count": "\(current.totalRecords)",
                                    "difference": "\(countDifference)",
                                    "tolerance": "\(countTolerance)",
                                  ]))
    }

    // Check bridge-specific record counts with relative deltas
    for bridgeId in sample.bridgeIds {
      let baselineCount = baseline.bridgeRecordCounts[bridgeId] ?? 0
      let currentCount = current.bridgeRecordCounts[bridgeId] ?? 0

      if baselineCount > 0 || currentCount > 0 {
        let relativeDelta = Double(abs(currentCount - baselineCount)) / max(Double(max(baselineCount, currentCount)), config.epsilon)

        if relativeDelta > config.countTolerancePct {
          changes.append(OutputChange(changeType: .count,
                                      affectedField: "bridge_\(bridgeId)_records",
                                      baselineValue: "\(baselineCount)",
                                      currentValue: "\(currentCount)",
                                      severity: relativeDelta > 0.1 ? .major : .minor,
                                      likelyCause: "Bridge-specific data processing changes",
                                      metadata: [
                                        "bridge_id": bridgeId,
                                        "baseline_count": "\(baselineCount)",
                                        "current_count": "\(currentCount)",
                                        "relative_delta": String(format: "%.4f", relativeDelta),
                                        "tolerance": String(format: "%.4f", config.countTolerancePct),
                                      ]))
        }
      }
    }

    // Check time-based distribution using chi-square test
    let timeDistributionChange = compareTimeDistributions(baseline: baseline.timeDistribution,
                                                          current: current.timeDistribution)

    if timeDistributionChange.isSignificant {
      changes.append(OutputChange(changeType: .count,
                                  affectedField: "time_distribution",
                                  baselineValue: baseline.timeDistribution.description,
                                  currentValue: current.timeDistribution.description,
                                  severity: timeDistributionChange.severity,
                                  likelyCause: "Time-based data processing or filtering changes",
                                  metadata: [
                                    "chi_square_statistic": String(format: "%.4f", timeDistributionChange.chiSquare),
                                    "p_value": String(format: "%.4f", timeDistributionChange.pValue),
                                    "significance_threshold": "0.05",
                                  ]))
    }

    return changes
  }

  /// Validates range parity (data value ranges and distributions)
  private func validateRangeParity(baseline: BaselineMetrics, current: CurrentOutput, sample _: GoldenSample) -> [OutputChange] {
    var changes: [OutputChange] = []

    // Check numeric field ranges
    let numericFields = ["cross_k", "cross_n", "via_penalty_sec", "gate_anom", "alternates_total"]

    for field in numericFields {
      let baselineRange = baseline.fieldRanges[field]
      let currentRange = current.fieldRanges[field]

      if let baselineRange = baselineRange, let currentRange = currentRange {
        // Check for NaN/Inf values (automatic critical)
        if baselineRange.hasNaNOrInf || currentRange.hasNaNOrInf {
          changes.append(OutputChange(changeType: .range,
                                      affectedField: field,
                                      baselineValue: baselineRange.description,
                                      currentValue: currentRange.description,
                                      severity: .critical,
                                      likelyCause: "Data corruption or calculation errors",
                                      metadata: [
                                        "baseline_has_nan_inf": "\(baselineRange.hasNaNOrInf)",
                                        "current_has_nan_inf": "\(currentRange.hasNaNOrInf)",
                                        "baseline_values": "min:\(baselineRange.min), max:\(baselineRange.max), mean:\(baselineRange.mean)",
                                        "current_values": "min:\(currentRange.min), max:\(currentRange.max), mean:\(currentRange.mean)",
                                      ]))
          continue
        }

        // Compare ranges with tolerance
        if !baselineRange.isSimilar(to: currentRange, tolerance: config.rangeTolerancePct) {
          changes.append(OutputChange(changeType: .range,
                                      affectedField: field,
                                      baselineValue: baselineRange.description,
                                      currentValue: currentRange.description,
                                      severity: .major,
                                      likelyCause: "Data transformation or calculation changes",
                                      metadata: [
                                        "baseline_range": "min:\(baselineRange.min), max:\(baselineRange.max), mean:\(baselineRange.mean)",
                                        "current_range": "min:\(currentRange.min), max:\(currentRange.max), mean:\(currentRange.mean)",
                                        "tolerance": String(format: "%.4f", config.rangeTolerancePct),
                                      ]))
        }
      }
    }

    // Check categorical field distributions
    let categoricalFields = ["bridge_id", "via_routable", "open_label"]

    for field in categoricalFields {
      let baselineDistribution = baseline.fieldDistributions[field]
      let currentDistribution = current.fieldDistributions[field]

      if let baselineDistribution = baselineDistribution, let currentDistribution = currentDistribution {
        let distributionChange = compareFieldDistributions(baseline: baselineDistribution,
                                                           current: currentDistribution)

        if distributionChange.isSignificant {
          changes.append(OutputChange(changeType: .range,
                                      affectedField: field,
                                      baselineValue: baselineDistribution.description,
                                      currentValue: currentDistribution.description,
                                      severity: distributionChange.severity,
                                      likelyCause: "Data filtering or categorization changes",
                                      metadata: [
                                        "chi_square_statistic": String(format: "%.4f", distributionChange.chiSquare),
                                        "p_value": String(format: "%.4f", distributionChange.pValue),
                                        "missing_keys": distributionChange.missingKeys.joined(separator: ","),
                                        "new_keys": distributionChange.newKeys.joined(separator: ","),
                                      ]))
        }
      }
    }

    return changes
  }

  /// Validates performance parity (timing and memory consistency)
  private func validatePerformanceParity(baseline: BaselineMetrics, current: CurrentOutput) -> [OutputChange] {
    var changes: [OutputChange] = []

    // Check pipeline timing with tolerance
    let timingTolerance = config.perfTolerancePct
    if !baseline.pipelineTime.isWithin(tolerance: timingTolerance, of: current.pipelineTime) {
      changes.append(OutputChange(changeType: .performance,
                                  affectedField: "pipeline_time",
                                  baselineValue: "\(baseline.pipelineTime)s",
                                  currentValue: "\(current.pipelineTime)s",
                                  severity: .minor,
                                  likelyCause: "Performance optimizations or regressions",
                                  metadata: [
                                    "baseline_time": "\(baseline.pipelineTime)",
                                    "current_time": "\(current.pipelineTime)",
                                    "tolerance": String(format: "%.4f", timingTolerance),
                                    "relative_change": String(format: "%.2f%%",
                                                              ((current.pipelineTime - baseline.pipelineTime) / baseline.pipelineTime) * 100),
                                  ]))
    }

    // Check memory usage with tolerance
    let memoryTolerance = config.perfTolerancePct
    if !baseline.peakMemory.isWithin(tolerance: memoryTolerance, of: current.peakMemory) {
      changes.append(OutputChange(changeType: .performance,
                                  affectedField: "peak_memory",
                                  baselineValue: "\(baseline.peakMemory)MB",
                                  currentValue: "\(current.peakMemory)MB",
                                  severity: .minor,
                                  likelyCause: "Memory management or data structure changes",
                                  metadata: [
                                    "baseline_memory": "\(baseline.peakMemory)",
                                    "current_memory": "\(current.peakMemory)",
                                    "tolerance": String(format: "%.4f", memoryTolerance),
                                    "relative_change": String(format: "%.2f%%",
                                                              ((current.peakMemory - baseline.peakMemory) / baseline.peakMemory) * 100),
                                  ]))
    }

    // Check stage timings
    for (stage, baselineTime) in baseline.stageTimings {
      if let currentTime = current.stageTimings[stage] {
        if !baselineTime.isWithin(tolerance: timingTolerance, of: currentTime) {
          changes.append(OutputChange(changeType: .performance,
                                      affectedField: "stage_\(stage)",
                                      baselineValue: "\(baselineTime)s",
                                      currentValue: "\(currentTime)s",
                                      severity: .minor,
                                      likelyCause: "Stage-specific performance changes",
                                      metadata: [
                                        "stage": stage,
                                        "baseline_time": "\(baselineTime)",
                                        "current_time": "\(currentTime)",
                                        "tolerance": String(format: "%.4f", timingTolerance),
                                      ]))
        }
      }
    }

    return changes
  }

  /// Validates schema parity (data schema consistency)
  private func validateSchemaParity(baseline: BaselineMetrics, current: CurrentOutput) -> [OutputChange] {
    var changes: [OutputChange] = []

    // Check schema hash first (fast path)
    if baseline.schemaHash != current.schemaHash {
      changes.append(OutputChange(changeType: .schema,
                                  affectedField: "schema_hash",
                                  baselineValue: baseline.schemaHash,
                                  currentValue: current.schemaHash,
                                  severity: .critical,
                                  likelyCause: "Schema definition or data transformation changes",
                                  metadata: [
                                    "baseline_hash": baseline.schemaHash,
                                    "current_hash": current.schemaHash,
                                    "hash_difference": "Schema structure has changed",
                                  ]))

      // If schema hash differs, analyze the specific changes
      let schemaDiff = analyzeSchemaDifferences(baseline: baseline.schema,
                                                current: current.schema)

      if !schemaDiff.addedFields.isEmpty || !schemaDiff.removedFields.isEmpty || !schemaDiff.renamedFields.isEmpty || !schemaDiff.typeChanges.isEmpty {
        changes.append(OutputChange(changeType: .schema,
                                    affectedField: "schema_structure",
                                    baselineValue: "Stable schema",
                                    currentValue: "Modified schema",
                                    severity: .critical,
                                    likelyCause: "Schema modifications detected",
                                    metadata: [
                                      "added_fields": schemaDiff.addedFields.joined(separator: ","),
                                      "removed_fields": schemaDiff.removedFields.joined(separator: ","),
                                      "renamed_fields": schemaDiff.renamedFields.joined(separator: ","),
                                      "type_changes": schemaDiff.typeChanges.joined(separator: ","),
                                    ]))
      }
    }

    // Check if required fields are present
    let requiredFields = ["v", "ts_utc", "bridge_id", "cross_k", "cross_n"]

    for field in requiredFields {
      if !current.schema.fields.contains(field) {
        changes.append(OutputChange(changeType: .schema,
                                    affectedField: field,
                                    baselineValue: "Present",
                                    currentValue: "Missing",
                                    severity: .critical,
                                    likelyCause: "Schema definition or data transformation changes",
                                    metadata: [
                                      "missing_field": field,
                                      "required": "true",
                                    ]))
      }
    }

    // Check field types
    let fieldTypes = baseline.schema.fieldTypes
    let currentFieldTypes = current.schema.fieldTypes

    for (field, expectedType) in fieldTypes {
      if let currentType = currentFieldTypes[field], currentType != expectedType {
        changes.append(OutputChange(changeType: .schema,
                                    affectedField: field,
                                    baselineValue: expectedType,
                                    currentValue: currentType,
                                    severity: .major,
                                    likelyCause: "Data type conversion or schema changes",
                                    metadata: [
                                      "field": field,
                                      "baseline_type": expectedType,
                                      "current_type": currentType,
                                      "type_change": "\(expectedType) → \(currentType)",
                                    ]))
      }
    }

    return changes
  }

  // MARK: - Analysis Methods

  /// Analyzes which module likely caused the detected changes
  private func analyzeModuleImpact(changes: [OutputChange]) -> (primaryModule: Module, confidence: Double) {
    // Analyze change patterns to identify likely source module
    let criticalChanges = changes.filter { $0.severity == .critical }
    let majorChanges = changes.filter { $0.severity == .major }

    // Shape changes typically indicate data processing pipeline issues
    if criticalChanges.contains(where: { $0.changeType == .shape }) {
      return (.bridgeDataProcessor, 0.9)
    }

    // Count changes often indicate data ingestion or filtering issues
    if criticalChanges.contains(where: { $0.changeType == .count }) {
      return (.bridgeDataService, 0.85)
    }

    // Range changes suggest data transformation issues
    if majorChanges.contains(where: { $0.changeType == .range }) {
      return (.bridgeDataProcessor, 0.8)
    }

    // Schema changes indicate type or structure modifications
    if criticalChanges.contains(where: { $0.changeType == .schema }) {
      return (.schema, 0.95)
    }

    // Performance changes could be in any module
    if changes.contains(where: { $0.changeType == .performance }) {
      return (.mlPipelineBackgroundManager, 0.7)
    }

    return (.orchestrator, 0.5) // Default fallback
  }

  /// Gets ranked list of likely affected modules
  private func getRankedLikelyModules(changes: [OutputChange]) -> [Module] {
    var moduleScores: [Module: Double] = [:]

    for change in changes {
      let module = getModuleForChange(change)
      let score = getChangeScore(change)
      moduleScores[module, default: 0] += score
    }

    return moduleScores.sorted { $0.value > $1.value }.map { $0.key }
  }

  /// Maps change types to likely modules
  private func getModuleForChange(_ change: OutputChange) -> Module {
    switch change.changeType {
    case .shape: return .bridgeDataProcessor
    case .count: return .bridgeDataService
    case .range: return .bridgeDataProcessor
    case .performance: return .mlPipelineBackgroundManager
    case .schema: return .schema
    case .validation: return .dataValidation
    }
  }

  /// Gets score for change severity
  private func getChangeScore(_ change: OutputChange) -> Double {
    switch change.severity {
    case .critical: return 10.0
    case .major: return 5.0
    case .minor: return 2.0
    case .informational: return 0.5
    }
  }

  /// Generates a human-readable failure reason
  private func generateFailureReason(changes: [OutputChange]) -> String {
    let criticalCount = changes.filter { $0.severity == .critical }.count
    let majorCount = changes.filter { $0.severity == .major }.count

    if criticalCount > 0 {
      return "Critical changes detected: \(criticalCount) critical, \(majorCount) major changes affecting output consistency"
    } else if majorCount > 0 {
      return "Major changes detected: \(majorCount) significant changes that may affect output quality"
    } else {
      return "Minor changes detected: \(changes.count) changes that don't affect core functionality"
    }
  }

  /// Calculates confidence level of the analysis
  private func calculateConfidence(changes: [OutputChange]) -> Double {
    let totalChanges = Double(changes.count)
    let criticalChanges = Double(changes.filter { $0.severity == .critical }.count)
    let majorChanges = Double(changes.filter { $0.severity == .major }.count)

    // Higher confidence with more specific, severe changes
    let severityScore = (criticalChanges * 0.9 + majorChanges * 0.7) / totalChanges
    let changeSpecificity = min(totalChanges / 10.0, 1.0) // More changes = more specific

    return min(severityScore * changeSpecificity, 1.0)
  }

  /// Generates guidance for loop-back to problematic module
  private func getLoopbackGuidance(failure: String?,
                                   affectedModule: Module?,
                                   changes: [OutputChange]) -> String?
  {
    guard let failure = failure, let affectedModule = affectedModule else {
      return nil
    }

    var guidance = "🔄 LOOP BACK REQUIRED\n\n"
    guidance += "Parity validation failed: \(failure)\n"
    guidance += "Affected module: \(affectedModule.rawValue)\n"
    guidance += "Module description: \(affectedModule.description)\n\n"

    guidance += "Recommended actions:\n"
    guidance += "1. Revert changes to \(affectedModule.rawValue)\n"
    guidance += "2. Re-run the module extraction\n"
    guidance += "3. Re-validate parity\n"
    guidance += "4. If issues persist, investigate related modules\n\n"

    guidance += "Specific changes detected:\n"
    for change in changes.prefix(5) { // Show top 5 changes
      guidance += "• \(change.changeType.rawValue): \(change.affectedField) - \(change.baselineValue) → \(change.currentValue)\n"
    }

    if changes.count > 5 {
      guidance += "• ... and \(changes.count - 5) more changes\n"
    }

    return guidance
  }

  // MARK: - Helper Methods

  /// Compares time distributions using chi-square test
  private func compareTimeDistributions(baseline: TimeDistribution, current: TimeDistribution) -> DistributionChange {
    // Implement chi-square test for time distribution comparison
    let chiSquare = calculateChiSquare(baseline: baseline.hourlyDistribution, current: current.hourlyDistribution)
    let pValue = calculatePValue(chiSquare: chiSquare, degreesOfFreedom: 23) // 24 hours - 1

    return DistributionChange(isSignificant: pValue < 0.05,
                              chiSquare: chiSquare,
                              pValue: pValue,
                              severity: pValue < 0.01 ? .critical : .major)
  }

  /// Compares field distributions using chi-square test
  private func compareFieldDistributions(baseline: FieldDistribution, current: FieldDistribution) -> DistributionChange {
    // Implement chi-square test for field distribution comparison
    let chiSquare = calculateChiSquare(baseline: baseline.values, current: current.values)
    let degreesOfFreedom = max(baseline.values.count, current.values.count) - 1
    let pValue = calculatePValue(chiSquare: chiSquare, degreesOfFreedom: degreesOfFreedom)

    let missingKeys = Set(baseline.values.keys).subtracting(Set(current.values.keys))
    let newKeys = Set(current.values.keys).subtracting(Set(baseline.values.keys))

    return DistributionChange(isSignificant: pValue < 0.05 || !missingKeys.isEmpty || !newKeys.isEmpty,
                              chiSquare: chiSquare,
                              pValue: pValue,
                              severity: pValue < 0.01 || !missingKeys.isEmpty || !newKeys.isEmpty ? .critical : .major,
                              missingKeys: Array(missingKeys),
                              newKeys: Array(newKeys))
  }

  /// Analyzes schema differences between baseline and current
  private func analyzeSchemaDifferences(baseline: DataSchema, current: DataSchema) -> SchemaDiff {
    let baselineFields = Set(baseline.fields)
    let currentFields = Set(current.fields)

    let addedFields = currentFields.subtracting(baselineFields)
    let removedFields = baselineFields.subtracting(currentFields)

    let renamedFields: [String] = []
    var typeChanges: [String] = []

    // Check for type changes in common fields
    for field in baselineFields.intersection(currentFields) {
      if baseline.fieldTypes[field] != current.fieldTypes[field] {
        typeChanges.append("\(field): \(baseline.fieldTypes[field] ?? "unknown") → \(current.fieldTypes[field] ?? "unknown")")
      }
    }

    return SchemaDiff(addedFields: Array(addedFields),
                      removedFields: Array(removedFields),
                      renamedFields: renamedFields,
                      typeChanges: typeChanges)
  }

  // MARK: - Statistical Methods

  /// Calculates chi-square statistic for distribution comparison
  private func calculateChiSquare(baseline: [String: Int], current: [String: Int]) -> Double {
    var chiSquare = 0.0
    let allKeys = Set(baseline.keys).union(Set(current.keys))

    for key in allKeys {
      let baselineValue = Double(baseline[key] ?? 0)
      let currentValue = Double(current[key] ?? 0)

      if baselineValue > 0 {
        let expected = baselineValue
        let observed = currentValue
        chiSquare += pow(observed - expected, 2) / expected
      }
    }

    return chiSquare
  }

  /// Calculates chi-square statistic for hourly distribution comparison
  private func calculateChiSquare(baseline: [Int: Int], current: [Int: Int]) -> Double {
    var chiSquare = 0.0

    for hour in 0 ..< 24 {
      let baselineValue = Double(baseline[hour] ?? 0)
      let currentValue = Double(current[hour] ?? 0)

      if baselineValue > 0 {
        let expected = baselineValue
        let observed = currentValue
        chiSquare += pow(observed - expected, 2) / expected
      }
    }

    return chiSquare
  }

  /// Calculates p-value for chi-square statistic
  private func calculatePValue(chiSquare: Double, degreesOfFreedom: Int) -> Double {
    // Simplified chi-square p-value calculation
    // In production, use a proper statistical library
    if degreesOfFreedom <= 0 { return 1.0 }

    // Approximate p-value using chi-square distribution
    let criticalValues: [Double] = [3.84, 5.99, 7.81, 9.49, 11.07, 12.59, 14.07, 15.51, 16.92, 18.31]
    let pValues: [Double] = [0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05, 0.05]

    if degreesOfFreedom <= 10 {
      let index = degreesOfFreedom - 1
      return chiSquare > criticalValues[index] ? pValues[index] : 1.0
    }

    // For higher degrees of freedom, use approximation
    return chiSquare > Double(degreesOfFreedom) + 2 * sqrt(Double(degreesOfFreedom)) ? 0.05 : 1.0
  }
}

// MARK: - Supporting Types

/// Distribution change analysis result
struct DistributionChange {
  let isSignificant: Bool
  let chiSquare: Double
  let pValue: Double
  let severity: PipelineParityValidator.ChangeSeverity
  let missingKeys: [String]
  let newKeys: [String]

  init(isSignificant: Bool, chiSquare: Double, pValue: Double, severity: PipelineParityValidator.ChangeSeverity, missingKeys: [String] = [], newKeys: [String] = []) {
    self.isSignificant = isSignificant
    self.chiSquare = chiSquare
    self.pValue = pValue
    self.severity = severity
    self.missingKeys = missingKeys
    self.newKeys = newKeys
  }
}

/// Schema difference analysis result
struct SchemaDiff {
  let addedFields: [String]
  let removedFields: [String]
  let renamedFields: [String]
  let typeChanges: [String]
}

/// Baseline metrics for comparison
struct BaselineMetrics: Codable {
  let outputStructure: String
  let fieldCount: Int
  let bridgeRecordCounts: [String: Int]
  let timeDistribution: TimeDistribution
  let fieldRanges: [String: ValueRange]
  let fieldDistributions: [String: FieldDistribution]
  let pipelineTime: TimeInterval
  let peakMemory: Double
  let schema: DataSchema
  let schemaHash: String
  let stageTimings: [String: TimeInterval]
  let memoryMetrics: MemoryMetrics
  let deterministicSeedUsed: Bool
}

/// Current pipeline output for comparison
struct CurrentOutput: Codable {
  let outputStructure: String
  let fieldCount: Int
  let totalRecords: Int
  let bridgeRecordCounts: [String: Int]
  let timeDistribution: TimeDistribution
  let fieldRanges: [String: ValueRange]
  let fieldDistributions: [String: FieldDistribution]
  let pipelineTime: TimeInterval
  let peakMemory: Double
  let schema: DataSchema
  let schemaHash: String
  let stageTimings: [String: TimeInterval]
  let memoryMetrics: MemoryMetrics
}

/// Golden sample data for validation
struct GoldenSample: Codable {
  let name: String
  let expectedRecordCount: Int
  let bridgeIds: [String]
  let dataQuality: DataQuality
}

/// Time distribution for validation
struct TimeDistribution: Codable {
  let hourlyDistribution: [Int: Int]
  let description: String
}

/// Value range for validation
struct ValueRange: Codable {
  let min: Double
  let max: Double
  let mean: Double
  let description: String

  var hasNaNOrInf: Bool {
    min.isNaN || max.isNaN || mean.isNaN || min.isInfinite || max.isInfinite || mean.isInfinite
  }

  func isSimilar(to other: ValueRange, tolerance: Double) -> Bool {
    let minDiff = abs(min - other.min) / Swift.max(abs(min), 1.0)
    let maxDiff = abs(max - other.max) / Swift.max(abs(max), 1.0)
    let meanDiff = abs(mean - other.mean) / Swift.max(abs(mean), 1.0)

    return minDiff <= tolerance && maxDiff <= tolerance && meanDiff <= tolerance
  }
}

/// Field distribution for validation
struct FieldDistribution: Codable {
  let values: [String: Int]
  let description: String
}

/// Data schema for validation
struct DataSchema: Codable {
  let fields: [String]
  let fieldTypes: [String: String]
}

/// Data quality metrics
struct DataQuality: Codable {
  let validationFailures: Int
  let correctedRows: Int
  let completeness: Double
}

/// Memory usage metrics
struct MemoryMetrics: Codable {
  let peakMemory: Double
  let averageMemory: Double
  let memoryEfficiency: Double

  var description: String {
    "Peak: \(peakMemory)MB, Avg: \(averageMemory)MB, Efficiency: \(memoryEfficiency)"
  }
}

// MARK: - Extensions

extension TimeInterval {
  func isWithin(tolerance: Double, of other: TimeInterval) -> Bool {
    let difference = abs(self - other)
    let maxValue = max(self, other)
    return difference / maxValue <= tolerance
  }
}

// MARK: - Parity Gate Facade

/// Simple facade for running parity validation
enum ParityGate {
  /// Runs parity validation with baseline and current outputs
  /// - Parameters:
  ///   - baselineURL: URL to baseline metrics JSON file
  ///   - current: Current pipeline output
  ///   - sample: Golden sample for validation
  /// - Returns: Parity validation result
  /// - Throws: Validation errors or file reading errors
  static func run(baselineURL: URL, current: CurrentOutput, sample: GoldenSample) async throws -> PipelineParityValidator.ParityValidationResult {
    let baselineData = try Data(contentsOf: baselineURL)
    let baseline = try JSONDecoder.bridgeDecoder().decode(BaselineMetrics.self, from: baselineData)

    let validator = PipelineParityValidator(config: .default)

    return try await validator.validateParity(baseline: baseline,
                                              current: current,
                                              sample: sample)
  }
}
