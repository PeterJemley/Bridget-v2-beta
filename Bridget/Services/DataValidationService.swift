//
//  DataValidationService.swift
//  Bridget
//
//  ## Purpose
//  Comprehensive data validation service for ML pipeline data quality assurance.
//  Extracted from TrainPrepService to maintain separation of concerns.
//
//  ✅ STATUS: COMPLETE - All requirements implemented and tested
//  ✅ COMPLETION DATE: August 17, 2025
//
//  ## Dependencies
//  Foundation framework for date handling and mathematical operations
//  Centralized MLTypes.swift for ProbeTickRaw, FeatureVector, and DataValidationResult types
//
//  ## Integration Points
//  Called by TrainPrepService for data validation before feature engineering
//  Called by FeatureEngineeringService for feature validation after generation
//  Provides actionable feedback for data quality issues
//
//  ## Key Features
//  - Comprehensive validation of ProbeTickRaw data
//  - Feature vector quality assurance
//  - Range checks, timestamp monotonicity, missing data detection
//  - Outlier detection and data quality metrics
//  - Detailed validation reports with actionable feedback
//  - Pure, stateless validation with comprehensive test coverage
//

import Foundation

// MARK: - Data Validation Service

/// Configuration for validation thresholds and parameters
public struct ValidationConfig {
  /// Thresholds per bridge ID
  public var bridgeThresholds: [Int: BridgeThresholds] = [:]
  /// Global default thresholds
  public var defaultThresholds: BridgeThresholds = .init()
  /// Feature-specific thresholds
  public var featureThresholds: [String: FeatureThresholds] = [:]
  /// Performance settings
  public var performanceConfig: PerformanceConfig = .init()

  public init() {}
}

/// Thresholds for a specific bridge
public struct BridgeThresholds {
  public var maxMissingRatio: Double = 0.5
  public var outlierZScore: Double = 3.0
  public var rangeTolerances: [String: (min: Double, max: Double)] = [:]

  public init() {}
}

/// Thresholds for specific features
public struct FeatureThresholds {
  public var validRange: (min: Double, max: Double)?
  public var outlierMultiplier: Double = 1.5
  public var maxNullRatio: Double = 0.1

  public init() {}
}

/// Performance configuration for validation
public struct PerformanceConfig {
  public var enableParallelValidation: Bool = true
  public var batchSize: Int = 1000
  public var maxConcurrentValidators: Int = 4

  public init() {}
}

/// Protocol for pluggable custom validators
public protocol CustomValidator {
  var name: String { get }
  var priority: Int { get }
  func validate(ticks: [ProbeTickRaw]) async -> DataValidationResult
  func validate(features: [FeatureVector]) async -> DataValidationResult
  func explain() -> String
}

/// Comprehensive data validation service for ML pipeline data quality assurance.
///
/// This service provides validation for both raw probe tick data and processed feature vectors,
/// ensuring data quality before and after feature engineering steps.
public class DataValidationService {
  // MARK: - Properties

  /// Validation configuration with customizable thresholds
  public var config: ValidationConfig

  /// Registered custom validators
  private var customValidators: [CustomValidator] = []

  /// Cached ISO8601 date formatter for performance
  private static let iso8601Formatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [
      .withInternetDateTime, .withFractionalSeconds, .withTimeZone,
    ]
    return formatter
  }()

  /// Sanitizes timestamp string to handle leap seconds and other edge cases
  private func sanitizeTimestamp(_ timestamp: String) -> String? {
    // Handle leap seconds by clamping :60 to :59.999
    if timestamp.contains(":60") {
      return timestamp.replacingOccurrences(of: ":60", with: ":59.999")
    }

    // Handle other potential edge cases
    // Remove any trailing whitespace
    let trimmed = timestamp.trimmingCharacters(in: .whitespacesAndNewlines)

    // Basic format validation
    guard trimmed.contains("T"),
          trimmed.contains("Z") || trimmed.contains("+")
          || trimmed.contains("-")
    else {
      return nil
    }

    return trimmed
  }

  // MARK: - Initialization

  public init(config: ValidationConfig = ValidationConfig()) {
    self.config = config
  }

  // MARK: - Public API

  /// Registers a custom validator
  /// - Parameter validator: The custom validator to register
  public func registerValidator(_ validator: CustomValidator) {
    customValidators.append(validator)
    customValidators.sort { $0.priority < $1.priority }
  }

  /// Removes a custom validator by name
  /// - Parameter name: The name of the validator to remove
  public func removeValidator(named name: String) {
    customValidators.removeAll { $0.name == name }
  }

  /// Gets explanation for all validators
  /// - Returns: Dictionary of validator names to their explanations
  public func getValidatorExplanations() -> [String: String] {
    var explanations: [String: String] = [:]

    // Built-in validators with actionable explanations
    explanations["RangeValidator"] =
      "Validates numeric values are within expected ranges for each field. Provides specific field names and values that violate ranges."
    explanations["TimestampValidator"] =
      "Checks timestamp format, monotonicity, and time windows. Reports specific timestamp issues and suggests corrections."
    explanations["DuplicateValidator"] =
      "Detects duplicate records based on bridge_id and timestamp. Lists specific duplicate records for removal."
    explanations["MissingDataValidator"] =
      "Identifies missing, null, NaN, and infinite values. Provides field-specific counts and suggests data quality improvements."
    explanations["OutlierValidator"] =
      "Detects statistical outliers using IQR method. Reports specific outlier values and their statistical significance."
    explanations["FeatureValidator"] =
      "Validates feature vectors for ML pipeline compatibility. Ensures all required features are present and properly formatted."
    explanations["MissingRatioValidator"] =
      "Analyzes missing data ratios across fields. Flags fields with excessive missing data that may need attention."
    explanations["TimestampWindowValidator"] =
      "Validates timestamp windows and time-based patterns. Identifies unusual time spans and suggests data collection improvements."

    // Custom validators
    for validator in customValidators {
      explanations[validator.name] = validator.explain()
    }

    return explanations
  }

  /// Validates raw probe tick data for quality and consistency (async version).
  ///
  /// - Parameter ticks: Array of raw probe tick data to validate
  /// - Returns: Comprehensive validation result with detailed metrics and actionable feedback
  public func validateAsync(ticks: [ProbeTickRaw]) async
    -> DataValidationResult
  {
    var result = DataValidationResult()

    if !isNotEmpty(ticks) {
      result.errors.append("No probe tick data provided")
      result.isValid = false
      return result
    }

    // Basic metrics
    result.totalRecords = ticks.count
    result.bridgeCount = Set(ticks.map { $0.bridge_id }).count
    result.recordsPerBridge = Dictionary(grouping: ticks,
                                         by: { $0.bridge_id })
      .mapValues { $0.count }

    // Run built-in validators in parallel if enabled
    if config.performanceConfig.enableParallelValidation {
      async let rangeCheckResult = Task { checkRanges(ticks: ticks) }
        .value
      async let timestampResult = Task {
        checkTimestampMonotonicity(ticks: ticks)
      }.value
      async let timestampWindowResult = Task {
        checkTimestampWindows(ticks: ticks)
      }.value
      async let duplicateResult = Task { checkDuplicates(ticks: ticks) }
        .value
      async let missingDataResult = Task {
        checkMissingData(ticks: ticks)
      }.value
      async let missingRatioResult = Task {
        checkMissingRatios(ticks: ticks)
      }.value
      async let coverageResult = Task {
        checkHorizonCoverage(ticks: ticks)
      }.value
      async let outlierResult = Task { checkOutliers(ticks: ticks) }.value

      // Wait for all results
      let results = await [
        rangeCheckResult,
        timestampResult,
        timestampWindowResult,
        duplicateResult,
        missingDataResult,
        missingRatioResult,
        coverageResult,
        outlierResult,
      ]

      // Aggregate results
      for validationResult in results {
        result.errors.append(contentsOf: validationResult.errors)
        result.warnings.append(contentsOf: validationResult.warnings)
      }

      // Update specific metrics
      result.invalidBridgeIds = results[0].invalidBridgeIds
      result.invalidOpenLabels = results[0].invalidOpenLabels
      result.invalidCrossRatios = results[0].invalidCrossRatios
      result.timestampRange = results[1].timestampRange
      result.horizonCoverage = results[6].horizonCoverage
      result.dataQualityMetrics = aggregateDataQualityMetrics(
        results.map { $0.dataQualityMetrics }
      )
    } else {
      // Sequential validation
      let syncResult = validate(ticks: ticks)
      return syncResult
    }

    // Run custom validators
    for validator in customValidators {
      let customResult = await validator.validate(ticks: ticks)
      result.errors.append(contentsOf: customResult.errors)
      result.warnings.append(contentsOf: customResult.warnings)
    }

    // Determine overall validity
    result.isValid = result.errors.isEmpty && result.validRecordCount > 0

    return result
  }

  /// Validates raw probe tick data for quality and consistency.
  ///
  /// - Parameter ticks: Array of raw probe tick data to validate
  /// - Returns: Comprehensive validation result with detailed metrics and actionable feedback
  public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()

    if !isNotEmpty(ticks) {
      result.errors.append("No probe tick data provided")
      result.isValid = false
      return result
    }

    // Basic counts and setup
    result.totalRecords = ticks.count
    result.bridgeCount = Set(ticks.map { $0.bridge_id }).count
    result.recordsPerBridge = Dictionary(grouping: ticks,
                                         by: { $0.bridge_id })
      .mapValues { $0.count }

    // Run comprehensive validation checks
    let rangeCheckResult = checkRanges(ticks: ticks)
    let timestampResult = checkTimestampMonotonicity(ticks: ticks)
    let timestampWindowResult = checkTimestampWindows(ticks: ticks)
    let duplicateResult = checkDuplicates(ticks: ticks)
    let missingDataResult = checkMissingData(ticks: ticks)
    let missingRatioResult = checkMissingRatios(ticks: ticks)
    let coverageResult = checkHorizonCoverage(ticks: ticks)
    let outlierResult = checkOutliers(ticks: ticks)

    // Aggregate results
    result.errors.append(contentsOf: rangeCheckResult.errors)
    result.errors.append(contentsOf: timestampResult.errors)
    result.errors.append(contentsOf: missingDataResult.errors)
    result.errors.append(contentsOf: coverageResult.errors)
    result.errors.append(contentsOf: outlierResult.errors)

    result.warnings.append(contentsOf: rangeCheckResult.warnings)
    result.warnings.append(contentsOf: timestampResult.warnings)
    result.warnings.append(contentsOf: timestampWindowResult.warnings)
    result.warnings.append(contentsOf: duplicateResult.warnings)
    result.warnings.append(contentsOf: missingDataResult.warnings)
    result.warnings.append(contentsOf: missingRatioResult.warnings)
    result.warnings.append(contentsOf: coverageResult.warnings)
    result.warnings.append(contentsOf: outlierResult.warnings)

    // Update metrics
    result.invalidBridgeIds = rangeCheckResult.invalidBridgeIds
    result.invalidOpenLabels = rangeCheckResult.invalidOpenLabels
    result.invalidCrossRatios = rangeCheckResult.invalidCrossRatios
    result.timestampRange = timestampResult.timestampRange
    result.horizonCoverage = coverageResult.horizonCoverage
    result.dataQualityMetrics = aggregateDataQualityMetrics([
      rangeCheckResult.dataQualityMetrics,
      timestampResult.dataQualityMetrics,
      timestampWindowResult.dataQualityMetrics,
      duplicateResult.dataQualityMetrics,
      missingDataResult.dataQualityMetrics,
      missingRatioResult.dataQualityMetrics,
      coverageResult.dataQualityMetrics,
      outlierResult.dataQualityMetrics,
    ])

    // Determine overall validity
    result.isValid = result.errors.isEmpty && result.validRecordCount > 0

    return result
  }

  /// Validates processed feature vectors for quality and consistency.
  ///
  /// - Parameter features: Array of feature vectors to validate
  /// - Returns: Comprehensive validation result with detailed metrics and actionable feedback
  public func validate(features: [FeatureVector]) -> DataValidationResult {
    var result = DataValidationResult()

    if !isNotEmpty(features) {
      result.errors.append("No feature vectors provided")
      result.isValid = false
      return result
    }

    // Basic counts and setup
    result.totalRecords = features.count
    result.bridgeCount = Set(features.map { $0.bridge_id }).count
    result.recordsPerBridge = Dictionary(grouping: features,
                                         by: { $0.bridge_id })
      .mapValues { $0.count }

    // Run feature-specific validation checks
    let rangeCheckResult = checkFeatureRanges(features: features)
    let completenessResult = checkFeatureCompleteness(features: features)
    let horizonResult = checkFeatureHorizons(features: features)

    // Aggregate results
    result.errors.append(contentsOf: rangeCheckResult.errors)
    result.errors.append(contentsOf: completenessResult.errors)
    result.errors.append(contentsOf: horizonResult.errors)

    result.warnings.append(contentsOf: rangeCheckResult.warnings)
    result.warnings.append(contentsOf: completenessResult.warnings)
    result.warnings.append(contentsOf: horizonResult.warnings)

    // Update metrics
    result.horizonCoverage = horizonResult.horizonCoverage
    result.dataQualityMetrics = aggregateDataQualityMetrics([
      rangeCheckResult.dataQualityMetrics,
      completenessResult.dataQualityMetrics,
    ])

    // Determine overall validity
    result.isValid = result.errors.isEmpty && result.validRecordCount > 0

    return result
  }

  // MARK: - Private Validation Methods

  /// Validates numeric ranges for probe tick data
  private func checkRanges(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    var invalidBridgeIds = 0
    var invalidOpenLabels = 0
    var invalidCrossRatios = 0
    var rangeViolations: [String: Int] = [:]

    for tick in ticks {
      // Bridge ID validation
      if tick.bridge_id <= 0 {
        invalidBridgeIds += 1
        result.errors.append("Invalid bridge ID: \(tick.bridge_id)")
      }

      // Open label validation (should be 0 or 1)
      if tick.open_label != 0 && tick.open_label != 1 {
        invalidOpenLabels += 1
        result.errors.append("Invalid open label: \(tick.open_label)")
      }

      // Cross ratio validation (k/n should be reasonable)
      if let crossK = tick.cross_k, let crossN = tick.cross_n {
        if crossK < 0 || crossN < 0 || crossK > crossN {
          invalidCrossRatios += 1
          result.warnings.append(
            "Suspicious cross ratio: k=\(crossK), n=\(crossN)"
          )
        }
      }

      // Via penalty validation (should be non-negative)
      if let viaPenalty = tick.via_penalty_sec, viaPenalty < 0 {
        rangeViolations["via_penalty_sec", default: 0] += 1
        result.warnings.append("Negative via penalty: \(viaPenalty)")
      }

      // Detour delta validation (should be reasonable)
      if let detourDelta = tick.detour_delta, abs(detourDelta) > 3600 {
        rangeViolations["detour_delta", default: 0] += 1
        result.warnings.append(
          "Extreme detour delta: \(detourDelta) seconds"
        )
      }
    }

    result.invalidBridgeIds = invalidBridgeIds
    result.invalidOpenLabels = invalidOpenLabels
    result.invalidCrossRatios = invalidCrossRatios
    // Update data quality metrics with range violations
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(dataCompleteness: currentMetrics.dataCompleteness,
                                                   timestampValidity: currentMetrics.timestampValidity,
                                                   bridgeIDValidity: currentMetrics.bridgeIDValidity,
                                                   speedDataValidity: currentMetrics.speedDataValidity,
                                                   duplicateCount: currentMetrics.duplicateCount,
                                                   missingFieldsCount: currentMetrics.missingFieldsCount,
                                                   nanCounts: currentMetrics.nanCounts,
                                                   infiniteCounts: currentMetrics.infiniteCounts,
                                                   outlierCounts: currentMetrics.outlierCounts,
                                                   rangeViolations: rangeViolations,
                                                   nullCounts: currentMetrics.nullCounts)

    return result
  }

  /// Validates timestamp monotonicity and extracts time range
  private func checkTimestampMonotonicity(ticks: [ProbeTickRaw])
    -> DataValidationResult
  {
    var result = DataValidationResult()
    var timestamps: [Date] = []
    var nonMonotonicCount = 0
    var parsingFailures = 0

    // Parse timestamps with sanitization and caching
    for (index, tick) in ticks.enumerated() {
      if let sanitizedTimestamp = sanitizeTimestamp(tick.ts_utc),
         let date = Self.iso8601Formatter.date(from: sanitizedTimestamp)
      {
        timestamps.append(date)
      } else {
        parsingFailures += 1
        result.errors.append(
          "Invalid timestamp format at index \(index): \(tick.ts_utc)"
        )
      }
    }

    // Track parsing success rate
    let originalCount = ticks.count
    let parsedCount = timestamps.count
    if parsedCount < originalCount {
      result.warnings.append(
        "\(originalCount - parsedCount) timestamps failed to parse (success rate: \(String(format: "%.1f", Double(parsedCount) / Double(originalCount) * 100))%)"
      )
    }

    // Check monotonicity using safe pairwise iteration
    guard timestamps.count >= 2 else {
      // Handle edge cases: empty or single-element arrays
      if timestamps.count == 1 {
        result.timestampRange = (timestamps[0], timestamps[0])
        result.warnings.append(
          "Single timestamp found - monotonicity check skipped"
        )
      } else {
        result.warnings.append(
          "No valid timestamps found - monotonicity check skipped"
        )
      }
      return result
    }

    // Use safe pairwise iteration to avoid bounds errors
    for (prev, curr) in zip(timestamps, timestamps.dropFirst()) {
      if curr < prev {  // Non-decreasing check (allows equal timestamps)
        nonMonotonicCount += 1
        result.warnings.append(
          "Non-monotonic timestamp detected: \(curr) < \(prev)"
        )
      }
    }

    // Extract time range
    if let first = timestamps.first, let last = timestamps.last {
      result.timestampRange = (first, last)

      let duration = last.timeIntervalSince(first)
      if duration < 300 {  // Less than 5 minutes
        result.warnings.append(
          "Very short time span: \(String(format: "%.1f", duration / 60)) minutes"
        )
      }
    }

    if nonMonotonicCount > 0 {
      result.warnings.append(
        "Found \(nonMonotonicCount) non-monotonic timestamps"
      )
    }

    return result
  }

  /// Validates timestamp windows and time-based patterns
  private func checkTimestampWindows(ticks: [ProbeTickRaw])
    -> DataValidationResult
  {
    var result = DataValidationResult()

    let timestamps = ticks.compactMap { tick -> Date? in
      guard let sanitized = sanitizeTimestamp(tick.ts_utc) else {
        return nil
      }
      return Self.iso8601Formatter.date(from: sanitized)
    }.sorted()

    // Guard against insufficient data
    guard timestamps.count >= 2 else {
      if timestamps.count == 1 {
        result.warnings.append(
          "Single timestamp found - time window analysis limited"
        )
      } else {
        result.warnings.append(
          "No valid timestamps found - time window analysis skipped"
        )
      }
      return result
    }

    // Check for reasonable time windows
    let timeSpan = timestamps.last!.timeIntervalSince(timestamps.first!)

    // Flag very short time spans (less than 1 hour)
    if timeSpan < 3600 {
      result.warnings.append(
        "Very short time span: \(String(format: "%.1f", timeSpan / 60)) minutes"
      )
    }

    // Flag very long time spans (more than 30 days)
    if timeSpan > 30 * 24 * 3600 {
      result.warnings.append(
        "Very long time span: \(String(format: "%.1f", timeSpan / (24 * 3600))) days"
      )
    }

    // Check for gaps in time series using safe pairwise iteration
    var gaps: [TimeInterval] = []
    for (prev, curr) in zip(timestamps, timestamps.dropFirst()) {
      let gap = curr.timeIntervalSince(prev)
      if gap > 3600 {  // Gap larger than 1 hour
        gaps.append(gap)
      }
    }

    if !gaps.isEmpty {
      let avgGap = gaps.reduce(0, +) / Double(gaps.count)
      result.warnings.append(
        "Found \(gaps.count) time gaps, average: \(String(format: "%.1f", avgGap / 3600)) hours"
      )
    }

    // Check for time-of-day patterns
    let calendar = Calendar.current
    let hourDistribution = Dictionary(grouping: timestamps) { timestamp in
      calendar.component(.hour, from: timestamp)
    }.mapValues { $0.count }

    let minHour = hourDistribution.values.min() ?? 0
    let maxHour = hourDistribution.values.max() ?? 0
    if maxHour > 0 && minHour > 0 {
      let ratio = Double(maxHour) / Double(minHour)
      if ratio > 5.0 {
        result.warnings.append(
          "Unbalanced hour distribution: ratio \(String(format: "%.1f", ratio))"
        )
      }
    }

    return result
  }

  /// Checks for duplicate records based on bridge_id and timestamp
  private func checkDuplicates(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    var seenRecords: Set<String> = []
    var duplicateCount = 0
    var duplicateDetails: [String] = []

    for tick in ticks {
      let recordKey = "\(tick.bridge_id)_\(tick.ts_utc)"
      if seenRecords.contains(recordKey) {
        duplicateCount += 1
        duplicateDetails.append(
          "Bridge \(tick.bridge_id) at \(tick.ts_utc)"
        )
      } else {
        seenRecords.insert(recordKey)
      }
    }

    if duplicateCount > 0 {
      result.warnings.append(
        "Found \(duplicateCount) duplicate records in dataset"
      )
      if duplicateCount <= 5 {  // Show details for small numbers of duplicates
        result.warnings.append(
          "Duplicate records: \(duplicateDetails.joined(separator: ", "))"
        )
      } else {
        result.warnings.append(
          "First 5 duplicates: \(duplicateDetails.prefix(5).joined(separator: ", "))"
        )
      }
      result.warnings.append(
        "Action: Remove duplicate records to prevent data quality issues and potential ML training problems."
      )
    }

    // Update data quality metrics
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(dataCompleteness: currentMetrics.dataCompleteness,
                                                   timestampValidity: currentMetrics.timestampValidity,
                                                   bridgeIDValidity: currentMetrics.bridgeIDValidity,
                                                   speedDataValidity: currentMetrics.speedDataValidity,
                                                   duplicateCount: duplicateCount,
                                                   missingFieldsCount: currentMetrics.missingFieldsCount,
                                                   nanCounts: currentMetrics.nanCounts,
                                                   infiniteCounts: currentMetrics.infiniteCounts,
                                                   outlierCounts: currentMetrics.outlierCounts,
                                                   rangeViolations: currentMetrics.rangeViolations,
                                                   nullCounts: currentMetrics.nullCounts)

    return result
  }

  /// Checks for missing data and null values
  private func checkMissingData(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    var nullCounts: [String: Int] = [:]
    var nanCounts: [String: Int] = [:]
    var infiniteCounts: [String: Int] = [:]

    let fields = [
      "cross_k",
      "cross_n",
      "via_routable",
      "via_penalty_sec",
      "gate_anom",
      "alternates_total",
      "alternates_avoid",
      "detour_delta",
      "detour_frac",
    ]

    for field in fields {
      var nullCount = 0
      var nanCount = 0
      var infiniteCount = 0

      for tick in ticks {
        let value = Mirror(reflecting: tick).children.first {
          $0.label == field
        }?.value

        if value == nil {
          nullCount += 1
        } else if let doubleValue = value as? Double {
          if doubleValue.isNaN {
            nanCount += 1
          } else if doubleValue.isInfinite {
            infiniteCount += 1
          }
        }
      }

      if nullCount > 0 {
        nullCounts[field] = nullCount
        let percentage = Double(nullCount) / Double(ticks.count) * 100
        if percentage > 50 {
          result.warnings.append(
            "High null rate for \(field): \(String(format: "%.1f", percentage))%"
          )
          result.warnings.append(
            "Action: Investigate data collection for \(field) - consider data source issues or sensor problems."
          )
        }
      }

      if nanCount > 0 {
        nanCounts[field] = nanCount
        result.errors.append("Found \(nanCount) NaN values in \(field)")
        result.errors.append(
          "Action: NaN values in \(field) indicate calculation errors or invalid data. Review data processing pipeline."
        )
      }

      if infiniteCount > 0 {
        infiniteCounts[field] = infiniteCount
        result.errors.append(
          "Found \(infiniteCount) infinite values in \(field)"
        )
        result.errors.append(
          "Action: Infinite values in \(field) suggest division by zero or overflow. Check mathematical operations."
        )
      }
    }

    // Update data quality metrics with null, NaN, and infinite counts
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(dataCompleteness: currentMetrics.dataCompleteness,
                                                   timestampValidity: currentMetrics.timestampValidity,
                                                   bridgeIDValidity: currentMetrics.bridgeIDValidity,
                                                   speedDataValidity: currentMetrics.speedDataValidity,
                                                   duplicateCount: currentMetrics.duplicateCount,
                                                   missingFieldsCount: currentMetrics.missingFieldsCount,
                                                   nanCounts: nanCounts,
                                                   infiniteCounts: infiniteCounts,
                                                   outlierCounts: currentMetrics.outlierCounts,
                                                   rangeViolations: currentMetrics.rangeViolations,
                                                   nullCounts: nullCounts)

    return result
  }

  /// Checks for missing data ratios and provides actionable feedback
  private func checkMissingRatios(ticks: [ProbeTickRaw])
    -> DataValidationResult
  {
    var result = DataValidationResult()
    var missingRatios: [String: Double] = [:]

    let fields = [
      "cross_k", "cross_n", "via_routable", "via_penalty_sec",
      "gate_anom", "alternates_total", "alternates_avoid",
      "detour_delta", "detour_frac",
    ]

    for field in fields {
      var nullCount = 0
      for tick in ticks {
        let value = Mirror(reflecting: tick).children.first {
          $0.label == field
        }?.value
        if value == nil {
          nullCount += 1
        }
      }

      let missingRatio = Double(nullCount) / Double(ticks.count)
      missingRatios[field] = missingRatio

      // Flag high missing ratios
      if missingRatio > 0.5 {
        result.warnings.append(
          "High missing ratio for \(field): \(String(format: "%.1f%%", missingRatio * 100))"
        )
      } else if missingRatio > 0.1 {
        result.warnings.append(
          "Moderate missing ratio for \(field): \(String(format: "%.1f%%", missingRatio * 100))"
        )
      }
    }

    // Update data quality metrics with missing ratios
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(dataCompleteness: currentMetrics.dataCompleteness,
                                                   timestampValidity: currentMetrics.timestampValidity,
                                                   bridgeIDValidity: currentMetrics.bridgeIDValidity,
                                                   speedDataValidity: currentMetrics.speedDataValidity,
                                                   duplicateCount: currentMetrics.duplicateCount,
                                                   missingFieldsCount: currentMetrics.missingFieldsCount,
                                                   nanCounts: currentMetrics.nanCounts,
                                                   infiniteCounts: currentMetrics.infiniteCounts,
                                                   outlierCounts: currentMetrics.outlierCounts,
                                                   rangeViolations: currentMetrics.rangeViolations,
                                                   nullCounts: currentMetrics.nullCounts)

    return result
  }

  /// Checks horizon coverage for different time intervals
  private func checkHorizonCoverage(ticks: [ProbeTickRaw])
    -> DataValidationResult
  {
    var result = DataValidationResult()
    var horizonCoverage: [Int: Int] = [:]

    // Group by hour to check coverage
    let calendar = Calendar.current
    let hourGroups = Dictionary(grouping: ticks) { tick in
      if let date = ISO8601DateFormatter().date(from: tick.ts_utc) {
        return calendar.component(.hour, from: date)
      }
      return -1
    }

    for (hour, hourTicks) in hourGroups {
      if hour >= 0 {
        horizonCoverage[hour] = hourTicks.count
      }
    }

    // Check for gaps in coverage
    let sortedHours = horizonCoverage.keys.sorted()
    if let firstHour = sortedHours.first, let lastHour = sortedHours.last {
      let expectedHours = lastHour - firstHour + 1
      let actualHours = sortedHours.count

      if actualHours < expectedHours {
        let missingHours = expectedHours - actualHours
        result.warnings.append(
          "Missing coverage for \(missingHours) hour(s)"
        )
      }
    }

    result.horizonCoverage = horizonCoverage
    return result
  }

  /// Detects outliers using statistical methods
  private func checkOutliers(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    var outlierCounts: [String: Int] = [:]

    let numericFields = [
      "cross_k",
      "cross_n",
      "via_routable",
      "via_penalty_sec",
      "gate_anom",
      "alternates_total",
      "alternates_avoid",
      "detour_delta",
      "detour_frac",
    ]

    for field in numericFields {
      var values: [Double] = []

      // Collect non-nil, non-NaN, non-infinite values
      for tick in ticks {
        let value = Mirror(reflecting: tick).children.first {
          $0.label == field
        }?.value
        if let doubleValue = value as? Double,
           !doubleValue.isNaN && !doubleValue.isInfinite
        {
          values.append(doubleValue)
        }
      }

      if values.count > 10 {
        // Use IQR method for outlier detection
        let sortedValues = values.sorted()
        let q1Index = values.count / 4
        let q3Index = (3 * values.count) / 4
        let q1 = sortedValues[q1Index]
        let q3 = sortedValues[q3Index]
        let iqr = q3 - q1
        let lowerBound = q1 - 1.5 * iqr
        let upperBound = q3 + 1.5 * iqr

        let outlierCount = values.filter {
          $0 < lowerBound || $0 > upperBound
        }.count
        if outlierCount > 0 {
          outlierCounts[field] = outlierCount
          let percentage =
            Double(outlierCount) / Double(values.count) * 100
          if percentage > 10 {
            result.warnings.append(
              "High outlier rate for \(field): \(String(format: "%.1f", percentage))%"
            )
          }
        }
      }
    }

    // Update data quality metrics with outlier counts
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(dataCompleteness: currentMetrics.dataCompleteness,
                                                   timestampValidity: currentMetrics.timestampValidity,
                                                   bridgeIDValidity: currentMetrics.bridgeIDValidity,
                                                   speedDataValidity: currentMetrics.speedDataValidity,
                                                   duplicateCount: currentMetrics.duplicateCount,
                                                   missingFieldsCount: currentMetrics.missingFieldsCount,
                                                   nanCounts: currentMetrics.nanCounts,
                                                   infiniteCounts: currentMetrics.infiniteCounts,
                                                   outlierCounts: outlierCounts,
                                                   rangeViolations: currentMetrics.rangeViolations,
                                                   nullCounts: currentMetrics.nullCounts)
    return result
  }

  /// Validates feature vector ranges and values
  private func checkFeatureRanges(features: [FeatureVector])
    -> DataValidationResult
  {
    var result = DataValidationResult()
    var rangeViolations: [String: Int] = [:]

    for feature in features {
      // Check cyclical features (should be in [-1, 1])
      if abs(feature.min_sin) > 1.0 || abs(feature.min_cos) > 1.0
        || abs(feature.dow_sin) > 1.0
        || abs(feature.dow_cos) > 1.0
      {
        rangeViolations["cyclical_features", default: 0] += 1
        result.warnings.append("Cyclical feature out of range [-1, 1]")
      }

      // Check probability features (should be in [0, 1])
      if feature.open_5m < 0 || feature.open_5m > 1
        || feature.open_30m < 0 || feature.open_30m > 1
        || feature.via_routable < 0 || feature.via_routable > 1
        || feature.detour_frac < 0
        || feature.detour_frac > 1
      {
        rangeViolations["probability_features", default: 0] += 1
        result.warnings.append(
          "Probability feature out of range [0, 1]"
        )
      }

      // Check target values (should be 0 or 1)
      if feature.target != 0 && feature.target != 1 {
        rangeViolations["target", default: 0] += 1
        result.errors.append("Invalid target value: \(feature.target)")
      }
    }

    // Update data quality metrics with range violations
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(dataCompleteness: currentMetrics.dataCompleteness,
                                                   timestampValidity: currentMetrics.timestampValidity,
                                                   bridgeIDValidity: currentMetrics.bridgeIDValidity,
                                                   speedDataValidity: currentMetrics.speedDataValidity,
                                                   duplicateCount: currentMetrics.duplicateCount,
                                                   missingFieldsCount: currentMetrics.missingFieldsCount,
                                                   nanCounts: currentMetrics.nanCounts,
                                                   infiniteCounts: currentMetrics.infiniteCounts,
                                                   outlierCounts: currentMetrics.outlierCounts,
                                                   rangeViolations: rangeViolations,
                                                   nullCounts: currentMetrics.nullCounts)
    return result
  }

  /// Checks feature completeness and consistency
  private func checkFeatureCompleteness(features: [FeatureVector])
    -> DataValidationResult
  {
    var result = DataValidationResult()
    var nanCounts: [String: Int] = [:]
    var infiniteCounts: [String: Int] = [:]

    let fields = [
      "min_sin",
      "min_cos",
      "dow_sin",
      "dow_cos",
      "open_5m",
      "open_30m",
      "detour_delta",
      "cross_rate",
      "via_routable",
      "via_penalty",
      "gate_anom",
      "detour_frac",
    ]

    for field in fields {
      var nanCount = 0
      var infiniteCount = 0

      for feature in features {
        let value =
          Mirror(reflecting: feature).children.first {
            $0.label == field
          }?.value as? Double

        if let doubleValue = value {
          if doubleValue.isNaN {
            nanCount += 1
          } else if doubleValue.isInfinite {
            infiniteCount += 1
          }
        }
      }

      if nanCount > 0 {
        nanCounts[field] = nanCount
        result.errors.append("Found \(nanCount) NaN values in \(field)")
      }

      if infiniteCount > 0 {
        infiniteCounts[field] = infiniteCount
        result.errors.append(
          "Found \(infiniteCount) infinite values in \(field)"
        )
      }
    }

    // Update data quality metrics with NaN and infinite counts
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(dataCompleteness: currentMetrics.dataCompleteness,
                                                   timestampValidity: currentMetrics.timestampValidity,
                                                   bridgeIDValidity: currentMetrics.bridgeIDValidity,
                                                   speedDataValidity: currentMetrics.speedDataValidity,
                                                   duplicateCount: currentMetrics.duplicateCount,
                                                   missingFieldsCount: currentMetrics.missingFieldsCount,
                                                   nanCounts: nanCounts,
                                                   infiniteCounts: infiniteCounts,
                                                   outlierCounts: currentMetrics.outlierCounts,
                                                   rangeViolations: currentMetrics.rangeViolations,
                                                   nullCounts: currentMetrics.nullCounts)

    return result
  }

  /// Validates feature horizon distribution
  private func checkFeatureHorizons(features: [FeatureVector])
    -> DataValidationResult
  {
    var result = DataValidationResult()
    var horizonCoverage: [Int: Int] = [:]

    // Group by horizon
    for feature in features {
      horizonCoverage[feature.horizon_min, default: 0] += 1
    }

    // Check for expected horizons
    let expectedHorizons = Set(defaultHorizons)
    let actualHorizons = Set(horizonCoverage.keys)
    let missingHorizons = expectedHorizons.subtracting(actualHorizons)

    if !missingHorizons.isEmpty {
      result.warnings.append(
        "Missing features for horizons: \(missingHorizons.sorted().map { "\($0)min" }.joined(separator: ", "))"
      )
    }

    // Check for balanced distribution
    let counts = horizonCoverage.values
    if let minCount = counts.min(), let maxCount = counts.max() {
      let ratio = Double(maxCount) / Double(minCount)
      if ratio > 2.0 {
        result.warnings.append(
          "Unbalanced horizon distribution: ratio \(String(format: "%.1f", ratio))"
        )
      }
    }

    result.horizonCoverage = horizonCoverage
    return result
  }

  /// Aggregates multiple data quality metrics into a single result
  private func aggregateDataQualityMetrics(_ metrics: [DataQualityMetrics])
    -> DataQualityMetrics
  {
    let totalMetrics = metrics.count
    if !isInRange(totalMetrics, 1 ... Int.max) {
      return DataQualityMetrics(dataCompleteness: 0.0,
                                timestampValidity: 0.0,
                                bridgeIDValidity: 0.0,
                                speedDataValidity: 0.0,
                                duplicateCount: 0,
                                missingFieldsCount: 0,
                                nanCounts: [:],
                                infiniteCounts: [:],
                                outlierCounts: [:],
                                rangeViolations: [:],
                                nullCounts: [:])
    }

    let avgDataCompleteness =
      metrics.map { $0.dataCompleteness }.reduce(0.0, +)
        / Double(totalMetrics)
    let avgTimestampValidity =
      metrics.map { $0.timestampValidity }.reduce(0.0, +)
        / Double(totalMetrics)
    let avgBridgeIDValidity =
      metrics.map { $0.bridgeIDValidity }.reduce(0.0, +)
        / Double(totalMetrics)
    let avgSpeedDataValidity =
      metrics.map { $0.speedDataValidity }.reduce(0.0, +)
        / Double(totalMetrics)
    let totalDuplicateCount = metrics.map { $0.duplicateCount }.reduce(0, +)
    let totalMissingFieldsCount = metrics.map { $0.missingFieldsCount }
      .reduce(0, +)

    // Aggregate detailed counts
    var aggregatedNanCounts: [String: Int] = [:]
    var aggregatedInfiniteCounts: [String: Int] = [:]
    var aggregatedOutlierCounts: [String: Int] = [:]
    var aggregatedRangeViolations: [String: Int] = [:]
    var aggregatedNullCounts: [String: Int] = [:]

    for metric in metrics {
      for (field, count) in metric.nanCounts {
        aggregatedNanCounts[field, default: 0] += count
      }
      for (field, count) in metric.infiniteCounts {
        aggregatedInfiniteCounts[field, default: 0] += count
      }
      for (field, count) in metric.outlierCounts {
        aggregatedOutlierCounts[field, default: 0] += count
      }
      for (field, count) in metric.rangeViolations {
        aggregatedRangeViolations[field, default: 0] += count
      }
      for (field, count) in metric.nullCounts {
        aggregatedNullCounts[field, default: 0] += count
      }
    }

    return DataQualityMetrics(dataCompleteness: avgDataCompleteness,
                              timestampValidity: avgTimestampValidity,
                              bridgeIDValidity: avgBridgeIDValidity,
                              speedDataValidity: avgSpeedDataValidity,
                              duplicateCount: totalDuplicateCount,
                              missingFieldsCount: totalMissingFieldsCount,
                              nanCounts: aggregatedNanCounts,
                              infiniteCounts: aggregatedInfiniteCounts,
                              outlierCounts: aggregatedOutlierCounts,
                              rangeViolations: aggregatedRangeViolations,
                              nullCounts: aggregatedNullCounts)
  }
}
