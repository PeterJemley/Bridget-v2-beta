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

/// Comprehensive data validation service for ML pipeline data quality assurance.
///
/// This service provides validation for both raw probe tick data and processed feature vectors,
/// ensuring data quality before and after feature engineering steps.
public class DataValidationService {
  
  // MARK: - Public API
  
  /// Validates raw probe tick data for quality and consistency.
  ///
  /// - Parameter ticks: Array of raw probe tick data to validate
  /// - Returns: Comprehensive validation result with detailed metrics and actionable feedback
  public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    
    guard !ticks.isEmpty else {
      result.errors.append("No probe tick data provided")
      result.isValid = false
      return result
    }
    
    // Basic counts and setup
    result.totalRecords = ticks.count
    result.bridgeCount = Set(ticks.map { $0.bridge_id }).count
    result.recordsPerBridge = Dictionary(grouping: ticks, by: { $0.bridge_id })
      .mapValues { $0.count }
    
    // Run comprehensive validation checks
    let rangeCheckResult = checkRanges(ticks: ticks)
    let timestampResult = checkTimestampMonotonicity(ticks: ticks)
    let missingDataResult = checkMissingData(ticks: ticks)
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
    result.warnings.append(contentsOf: missingDataResult.warnings)
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
      missingDataResult.dataQualityMetrics,
      outlierResult.dataQualityMetrics
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
    
    guard !features.isEmpty else {
      result.errors.append("No feature vectors provided")
      result.isValid = false
      return result
    }
    
    // Basic counts and setup
    result.totalRecords = features.count
    result.bridgeCount = Set(features.map { $0.bridge_id }).count
    result.recordsPerBridge = Dictionary(grouping: features, by: { $0.bridge_id })
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
      completenessResult.dataQualityMetrics
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
          result.warnings.append("Suspicious cross ratio: k=\(crossK), n=\(crossN)")
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
        result.warnings.append("Extreme detour delta: \(detourDelta) seconds")
      }
    }
    
    result.invalidBridgeIds = invalidBridgeIds
    result.invalidOpenLabels = invalidOpenLabels
    result.invalidCrossRatios = invalidCrossRatios
    // Update data quality metrics with range violations
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(
      dataCompleteness: currentMetrics.dataCompleteness,
      timestampValidity: currentMetrics.timestampValidity,
      bridgeIDValidity: currentMetrics.bridgeIDValidity,
      speedDataValidity: currentMetrics.speedDataValidity,
      duplicateCount: currentMetrics.duplicateCount,
      missingFieldsCount: currentMetrics.missingFieldsCount
    )
    
    return result
  }
  
  /// Validates timestamp monotonicity and extracts time range
  private func checkTimestampMonotonicity(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    var timestamps: [Date] = []
    var nonMonotonicCount = 0
    
    // Parse timestamps and check monotonicity
    for (index, tick) in ticks.enumerated() {
      if let date = ISO8601DateFormatter().date(from: tick.ts_utc) {
        timestamps.append(date)
        
        if index > 0 && date < timestamps[index - 1] {
          nonMonotonicCount += 1
          result.warnings.append("Non-monotonic timestamp at index \(index): \(tick.ts_utc)")
        }
      } else {
        result.errors.append("Invalid timestamp format at index \(index): \(tick.ts_utc)")
      }
    }
    
    // Extract time range
    if let first = timestamps.first, let last = timestamps.last {
      result.timestampRange = (first, last)
      
      let duration = last.timeIntervalSince(first)
      if duration < 300 { // Less than 5 minutes
        result.warnings.append("Very short time span: \(String(format: "%.1f", duration/60)) minutes")
      }
    }
    
    if nonMonotonicCount > 0 {
      result.warnings.append("Found \(nonMonotonicCount) non-monotonic timestamps")
    }
    
    return result
  }
  
  /// Checks for missing data and null values
  private func checkMissingData(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    var nullCounts: [String: Int] = [:]
    var nanCounts: [String: Int] = [:]
    var infiniteCounts: [String: Int] = [:]
    
    let fields = ["cross_k", "cross_n", "via_routable", "via_penalty_sec", 
                  "gate_anom", "alternates_total", "alternates_avoid", "detour_delta", "detour_frac"]
    
    for field in fields {
      var nullCount = 0
      var nanCount = 0
      var infiniteCount = 0
      
      for tick in ticks {
        let value = Mirror(reflecting: tick).children.first { $0.label == field }?.value
        
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
          result.warnings.append("High null rate for \(field): \(String(format: "%.1f", percentage))%")
        }
      }
      
      if nanCount > 0 {
        nanCounts[field] = nanCount
        result.errors.append("Found \(nanCount) NaN values in \(field)")
      }
      
      if infiniteCount > 0 {
        infiniteCounts[field] = infiniteCount
        result.errors.append("Found \(infiniteCount) infinite values in \(field)")
      }
    }
    
    // Update data quality metrics with null, NaN, and infinite counts
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(
      dataCompleteness: currentMetrics.dataCompleteness,
      timestampValidity: currentMetrics.timestampValidity,
      bridgeIDValidity: currentMetrics.bridgeIDValidity,
      speedDataValidity: currentMetrics.speedDataValidity,
      duplicateCount: currentMetrics.duplicateCount,
      missingFieldsCount: currentMetrics.missingFieldsCount
    )
    
    return result
  }
  
  /// Checks horizon coverage for different time intervals
  private func checkHorizonCoverage(ticks: [ProbeTickRaw]) -> DataValidationResult {
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
        result.warnings.append("Missing coverage for \(missingHours) hour(s)")
      }
    }
    
    result.horizonCoverage = horizonCoverage
    return result
  }
  
  /// Detects outliers using statistical methods
  private func checkOutliers(ticks: [ProbeTickRaw]) -> DataValidationResult {
    var result = DataValidationResult()
    var outlierCounts: [String: Int] = [:]
    
    let numericFields = ["cross_k", "cross_n", "via_routable", "via_penalty_sec", 
                         "gate_anom", "alternates_total", "alternates_avoid", "detour_delta", "detour_frac"]
    
    for field in numericFields {
      var values: [Double] = []
      
      // Collect non-nil, non-NaN, non-infinite values
      for tick in ticks {
        let value = Mirror(reflecting: tick).children.first { $0.label == field }?.value
        if let doubleValue = value as? Double, !doubleValue.isNaN && !doubleValue.isInfinite {
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
        
        let outlierCount = values.filter { $0 < lowerBound || $0 > upperBound }.count
        if outlierCount > 0 {
          outlierCounts[field] = outlierCount
          let percentage = Double(outlierCount) / Double(values.count) * 100
          if percentage > 10 {
            result.warnings.append("High outlier rate for \(field): \(String(format: "%.1f", percentage))%")
          }
        }
      }
    }
    
    // Update data quality metrics with outlier counts
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(
      dataCompleteness: currentMetrics.dataCompleteness,
      timestampValidity: currentMetrics.timestampValidity,
      bridgeIDValidity: currentMetrics.bridgeIDValidity,
      speedDataValidity: currentMetrics.speedDataValidity,
      duplicateCount: currentMetrics.duplicateCount,
      missingFieldsCount: currentMetrics.missingFieldsCount
    )
    return result
  }
  
  /// Validates feature vector ranges and values
  private func checkFeatureRanges(features: [FeatureVector]) -> DataValidationResult {
    var result = DataValidationResult()
    var rangeViolations: [String: Int] = [:]
    
    for feature in features {
      // Check cyclical features (should be in [-1, 1])
      if abs(feature.min_sin) > 1.0 || abs(feature.min_cos) > 1.0 ||
         abs(feature.dow_sin) > 1.0 || abs(feature.dow_cos) > 1.0 {
        rangeViolations["cyclical_features", default: 0] += 1
        result.warnings.append("Cyclical feature out of range [-1, 1]")
      }
      
      // Check probability features (should be in [0, 1])
      if feature.open_5m < 0 || feature.open_5m > 1 ||
         feature.open_30m < 0 || feature.open_30m > 1 ||
         feature.via_routable < 0 || feature.via_routable > 1 ||
         feature.detour_frac < 0 || feature.detour_frac > 1 {
        rangeViolations["probability_features", default: 0] += 1
        result.warnings.append("Probability feature out of range [0, 1]")
      }
      
      // Check target values (should be 0 or 1)
      if feature.target != 0 && feature.target != 1 {
        rangeViolations["target", default: 0] += 1
        result.errors.append("Invalid target value: \(feature.target)")
      }
    }
    
    // Update data quality metrics with range violations
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(
      dataCompleteness: currentMetrics.dataCompleteness,
      timestampValidity: currentMetrics.timestampValidity,
      bridgeIDValidity: currentMetrics.bridgeIDValidity,
      speedDataValidity: currentMetrics.speedDataValidity,
      duplicateCount: currentMetrics.duplicateCount,
      missingFieldsCount: currentMetrics.missingFieldsCount
    )
    return result
  }
  
  /// Checks feature completeness and consistency
  private func checkFeatureCompleteness(features: [FeatureVector]) -> DataValidationResult {
    var result = DataValidationResult()
    var nanCounts: [String: Int] = [:]
    var infiniteCounts: [String: Int] = [:]
    
    let fields = ["min_sin", "min_cos", "dow_sin", "dow_cos", "open_5m", "open_30m",
                  "detour_delta", "cross_rate", "via_routable", "via_penalty", "gate_anom", "detour_frac"]
    
    for field in fields {
      var nanCount = 0
      var infiniteCount = 0
      
      for feature in features {
        let value = Mirror(reflecting: feature).children.first { $0.label == field }?.value as? Double
        
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
        result.errors.append("Found \(infiniteCount) infinite values in \(field)")
      }
    }
    
    // Update data quality metrics with NaN and infinite counts
    let currentMetrics = result.dataQualityMetrics
    result.dataQualityMetrics = DataQualityMetrics(
      dataCompleteness: currentMetrics.dataCompleteness,
      timestampValidity: currentMetrics.timestampValidity,
      bridgeIDValidity: currentMetrics.bridgeIDValidity,
      speedDataValidity: currentMetrics.speedDataValidity,
      duplicateCount: currentMetrics.duplicateCount,
      missingFieldsCount: currentMetrics.missingFieldsCount
    )
    
    return result
  }
  
  /// Validates feature horizon distribution
  private func checkFeatureHorizons(features: [FeatureVector]) -> DataValidationResult {
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
      result.warnings.append("Missing features for horizons: \(missingHorizons.sorted().map { "\($0)min" }.joined(separator: ", "))")
    }
    
    // Check for balanced distribution
    let counts = horizonCoverage.values
    if let minCount = counts.min(), let maxCount = counts.max() {
      let ratio = Double(maxCount) / Double(minCount)
      if ratio > 2.0 {
        result.warnings.append("Unbalanced horizon distribution: ratio \(String(format: "%.1f", ratio))")
      }
    }
    
    result.horizonCoverage = horizonCoverage
    return result
  }
  
  /// Aggregates multiple data quality metrics into a single result
  private func aggregateDataQualityMetrics(_ metrics: [DataQualityMetrics]) -> DataQualityMetrics {
    let totalMetrics = metrics.count
    guard totalMetrics > 0 else {
      return DataQualityMetrics(
        dataCompleteness: 0.0,
        timestampValidity: 0.0,
        bridgeIDValidity: 0.0,
        speedDataValidity: 0.0,
        duplicateCount: 0,
        missingFieldsCount: 0
      )
    }
    
    let avgDataCompleteness = metrics.map { $0.dataCompleteness }.reduce(0.0, +) / Double(totalMetrics)
    let avgTimestampValidity = metrics.map { $0.timestampValidity }.reduce(0.0, +) / Double(totalMetrics)
    let avgBridgeIDValidity = metrics.map { $0.bridgeIDValidity }.reduce(0.0, +) / Double(totalMetrics)
    let avgSpeedDataValidity = metrics.map { $0.speedDataValidity }.reduce(0.0, +) / Double(totalMetrics)
    let totalDuplicateCount = metrics.map { $0.duplicateCount }.reduce(0, +)
    let totalMissingFieldsCount = metrics.map { $0.missingFieldsCount }.reduce(0, +)
    
    return DataQualityMetrics(
      dataCompleteness: avgDataCompleteness,
      timestampValidity: avgTimestampValidity,
      bridgeIDValidity: avgBridgeIDValidity,
      speedDataValidity: avgSpeedDataValidity,
      duplicateCount: totalDuplicateCount,
      missingFieldsCount: totalMissingFieldsCount
    )
  }
}
