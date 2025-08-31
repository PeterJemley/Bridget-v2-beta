//
//  DataStatisticsService.swift
//  Bridget
//
//  ## Purpose
//  Comprehensive statistics and summary utilities for bridge data analysis.
//  Provides artifacts for counts by bridge & minute, first/last timestamps,
//  and horizon completeness details beyond just error messages.
//
//  ## Dependencies
//  Foundation framework, MLTypes
//
//  ## Integration Points
//  Used by validation services and ML pipeline for data quality analysis
//  Provides artifacts for reporting and debugging data completeness
//
//  ## Key Features
//  - Bridge & minute count statistics
//  - First/last timestamp analysis
//  - Horizon completeness details
//  - Data quality metrics and artifacts
//

import Foundation

// MARK: - Statistics Models

/// Comprehensive statistics for bridge data analysis
public struct BridgeDataStatistics: Codable {
  /// Overall data summary
  public let summary: DataSummary
  /// Bridge-specific statistics
  public let bridgeStats: [Int: BridgeStatistics]
  /// Time-based statistics
  public let timeStats: TimeStatistics
  /// Horizon coverage details
  public let horizonStats: HorizonStatistics
  /// Data quality metrics
  public let qualityMetrics: DataQualityMetrics

  public init(
    summary: DataSummary,
    bridgeStats: [Int: BridgeStatistics],
    timeStats: TimeStatistics,
    horizonStats: HorizonStatistics,
    qualityMetrics: DataQualityMetrics
  ) {
    self.summary = summary
    self.bridgeStats = bridgeStats
    self.timeStats = timeStats
    self.horizonStats = horizonStats
    self.qualityMetrics = qualityMetrics
  }
}

/// Overall data summary
public struct DataSummary: Codable {
  /// Total number of records
  public let totalRecords: Int
  /// Number of unique bridges
  public let uniqueBridges: Int
  /// Date range of data
  public let dateRange: DateRange
  /// Data completeness percentage
  public let completenessPercentage: Double

  public init(
    totalRecords: Int,
    uniqueBridges: Int,
    dateRange: DateRange,
    completenessPercentage: Double
  ) {
    self.totalRecords = totalRecords
    self.uniqueBridges = uniqueBridges
    self.dateRange = dateRange
    self.completenessPercentage = completenessPercentage
  }
}

/// Date range information
public struct DateRange: Codable {
  /// First timestamp in the dataset
  public let firstTimestamp: Date
  /// Last timestamp in the dataset
  public let lastTimestamp: Date
  /// Duration of the dataset
  public let duration: TimeInterval

  public init(firstTimestamp: Date, lastTimestamp: Date) {
    self.firstTimestamp = firstTimestamp
    self.lastTimestamp = lastTimestamp
    self.duration = lastTimestamp.timeIntervalSince(firstTimestamp)
  }
}

/// Bridge-specific statistics
public struct BridgeStatistics: Codable {
  /// Bridge ID
  public let bridgeID: Int
  /// Number of records for this bridge
  public let recordCount: Int
  /// First timestamp for this bridge
  public let firstTimestamp: Date
  /// Last timestamp for this bridge
  public let lastTimestamp: Date
  /// Counts by minute (hour:minute -> count)
  public let countsByMinute: [String: Int]
  /// Counts by hour (hour -> count)
  public let countsByHour: [Int: Int]
  /// Counts by day of week (0=Sunday, 1=Monday, etc.)
  public let countsByDayOfWeek: [Int: Int]
  /// Data completeness for this bridge
  public let completenessPercentage: Double

  public init(
    bridgeID: Int,
    recordCount: Int,
    firstTimestamp: Date,
    lastTimestamp: Date,
    countsByMinute: [String: Int],
    countsByHour: [Int: Int],
    countsByDayOfWeek: [Int: Int],
    completenessPercentage: Double
  ) {
    self.bridgeID = bridgeID
    self.recordCount = recordCount
    self.firstTimestamp = firstTimestamp
    self.lastTimestamp = lastTimestamp
    self.countsByMinute = countsByMinute
    self.countsByHour = countsByHour
    self.countsByDayOfWeek = countsByDayOfWeek
    self.completenessPercentage = completenessPercentage
  }
}

/// Time-based statistics
public struct TimeStatistics: Codable {
  /// Counts by minute across all bridges
  public let countsByMinute: [String: Int]
  /// Counts by hour across all bridges
  public let countsByHour: [Int: Int]
  /// Counts by day of week across all bridges
  public let countsByDayOfWeek: [Int: Int]
  /// Peak activity times
  public let peakActivityTimes: [String: Int]
  /// Low activity times
  public let lowActivityTimes: [String: Int]

  public init(
    countsByMinute: [String: Int],
    countsByHour: [Int: Int],
    countsByDayOfWeek: [Int: Int],
    peakActivityTimes: [String: Int],
    lowActivityTimes: [String: Int]
  ) {
    self.countsByMinute = countsByMinute
    self.countsByHour = countsByHour
    self.countsByDayOfWeek = countsByDayOfWeek
    self.peakActivityTimes = peakActivityTimes
    self.lowActivityTimes = lowActivityTimes
  }
}

/// Horizon coverage statistics
public struct HorizonStatistics: Codable {
  /// Available horizons in the data
  public let availableHorizons: [Int]
  /// Coverage by horizon (horizon -> coverage percentage)
  public let coverageByHorizon: [Int: Double]
  /// Bridge coverage by horizon (bridge -> horizon -> coverage)
  public let bridgeCoverageByHorizon: [Int: [Int: Double]]
  /// Missing horizons for each bridge
  public let missingHorizonsByBridge: [Int: [Int]]
  /// Gap analysis in horizon sequences
  public let horizonGaps: [Int: [Int]]
  /// Overall horizon completeness
  public let overallCompleteness: Double

  public init(
    availableHorizons: [Int],
    coverageByHorizon: [Int: Double],
    bridgeCoverageByHorizon: [Int: [Int: Double]],
    missingHorizonsByBridge: [Int: [Int]],
    horizonGaps: [Int: [Int]],
    overallCompleteness: Double
  ) {
    self.availableHorizons = availableHorizons
    self.coverageByHorizon = coverageByHorizon
    self.bridgeCoverageByHorizon = bridgeCoverageByHorizon
    self.missingHorizonsByBridge = missingHorizonsByBridge
    self.horizonGaps = horizonGaps
    self.overallCompleteness = overallCompleteness
  }
}

/// Data quality metrics
public struct DataQualityMetrics: Codable {
  /// Percentage of records with complete data
  public let dataCompleteness: Double
  /// Percentage of records with valid timestamps
  public let timestampValidity: Double
  /// Percentage of records with valid bridge IDs
  public let bridgeIDValidity: Double
  /// Percentage of records with valid speed data
  public let speedDataValidity: Double
  /// Number of duplicate records
  public let duplicateCount: Int
  /// Number of records with missing required fields
  public let missingFieldsCount: Int
  /// Count of NaN values by field name
  public let nanCounts: [String: Int]
  /// Count of infinite values by field name
  public let infiniteCounts: [String: Int]
  /// Count of outlier values by field name
  public let outlierCounts: [String: Int]
  /// Count of range violations by field name
  public let rangeViolations: [String: Int]
  /// Count of null values by field name
  public let nullCounts: [String: Int]

  public init(
    dataCompleteness: Double,
    timestampValidity: Double,
    bridgeIDValidity: Double,
    speedDataValidity: Double,
    duplicateCount: Int,
    missingFieldsCount: Int,
    nanCounts: [String: Int] = [:],
    infiniteCounts: [String: Int] = [:],
    outlierCounts: [String: Int] = [:],
    rangeViolations: [String: Int] = [:],
    nullCounts: [String: Int] = [:]
  ) {
    self.dataCompleteness = dataCompleteness
    self.timestampValidity = timestampValidity
    self.bridgeIDValidity = bridgeIDValidity
    self.speedDataValidity = speedDataValidity
    self.duplicateCount = duplicateCount
    self.missingFieldsCount = missingFieldsCount
    self.nanCounts = nanCounts
    self.infiniteCounts = infiniteCounts
    self.outlierCounts = outlierCounts
    self.rangeViolations = rangeViolations
    self.nullCounts = nullCounts
  }
}

// MARK: - Data Statistics Service

/// Service for generating comprehensive statistics and artifacts from bridge data
public class DataStatisticsService {
  /// Generates comprehensive statistics from probe tick data
  /// - Parameter ticks: Array of probe tick data
  /// - Returns: Complete statistics including bridge, time, and horizon analysis
  public func generateStatistics(from ticks: [ProbeTickRaw]) -> BridgeDataStatistics {
    let summary = generateSummary(from: ticks)
    let bridgeStats = generateBridgeStatistics(from: ticks)
    let timeStats = generateTimeStatistics(from: ticks)
    let horizonStats = generateHorizonStatistics(from: ticks)
    let qualityMetrics = generateQualityMetrics(from: ticks)

    return BridgeDataStatistics(
      summary: summary,
      bridgeStats: bridgeStats,
      timeStats: timeStats,
      horizonStats: horizonStats,
      qualityMetrics: qualityMetrics)
  }

  /// Generates comprehensive statistics from feature vectors
  /// - Parameter features: Array of feature vectors
  /// - Returns: Complete statistics including bridge, time, and horizon analysis
  public func generateStatistics(from features: [FeatureVector]) -> BridgeDataStatistics {
    let summary = generateSummary(from: features)
    let bridgeStats = generateBridgeStatistics(from: features)
    let timeStats = generateTimeStatistics(from: features)
    let horizonStats = generateHorizonStatistics(from: features)
    let qualityMetrics = generateQualityMetrics(from: features)

    return BridgeDataStatistics(
      summary: summary,
      bridgeStats: bridgeStats,
      timeStats: timeStats,
      horizonStats: horizonStats,
      qualityMetrics: qualityMetrics)
  }

  // MARK: - Private Methods

  private func generateSummary(from ticks: [ProbeTickRaw]) -> DataSummary {
    let totalRecords = ticks.count
    let uniqueBridges = Set(ticks.map { $0.bridge_id }).count

    let timestamps = ticks.compactMap { tick in
      ISO8601DateFormatter().date(from: tick.ts_utc)
    }.sorted()

    let dateRange = DateRange(
      firstTimestamp: timestamps.first ?? Date(),
      lastTimestamp: timestamps.last ?? Date())

    let completenessPercentage = calculateCompleteness(from: ticks)

    return DataSummary(
      totalRecords: totalRecords,
      uniqueBridges: uniqueBridges,
      dateRange: dateRange,
      completenessPercentage: completenessPercentage)
  }

  private func generateSummary(from features: [FeatureVector]) -> DataSummary {
    let totalRecords = features.count
    let uniqueBridges = Set(features.map { $0.bridge_id }).count

    // For features, we don't have direct timestamps, so we'll use a placeholder
    let dateRange = DateRange(
      firstTimestamp: Date(),
      lastTimestamp: Date())

    let completenessPercentage = calculateCompleteness(from: features)

    return DataSummary(
      totalRecords: totalRecords,
      uniqueBridges: uniqueBridges,
      dateRange: dateRange,
      completenessPercentage: completenessPercentage)
  }

  private func generateBridgeStatistics(from ticks: [ProbeTickRaw]) -> [Int: BridgeStatistics] {
    var bridgeStats: [Int: BridgeStatistics] = [:]

    let bridgeGroups = Dictionary(grouping: ticks) { $0.bridge_id }

    for (bridgeID, bridgeTicks) in bridgeGroups {
      let recordCount = bridgeTicks.count

      let timestamps = bridgeTicks.compactMap { tick in
        ISO8601DateFormatter().date(from: tick.ts_utc)
      }.sorted()

      let firstTimestamp = timestamps.first ?? Date()
      let lastTimestamp = timestamps.last ?? Date()

      let countsByMinute = calculateCountsByMinute(from: bridgeTicks)
      let countsByHour = calculateCountsByHour(from: bridgeTicks)
      let countsByDayOfWeek = calculateCountsByDayOfWeek(from: bridgeTicks)

      let completenessPercentage = calculateBridgeCompleteness(from: bridgeTicks)

      bridgeStats[bridgeID] = BridgeStatistics(
        bridgeID: bridgeID,
        recordCount: recordCount,
        firstTimestamp: firstTimestamp,
        lastTimestamp: lastTimestamp,
        countsByMinute: countsByMinute,
        countsByHour: countsByHour,
        countsByDayOfWeek: countsByDayOfWeek,
        completenessPercentage: completenessPercentage)
    }

    return bridgeStats
  }

  private func generateBridgeStatistics(from features: [FeatureVector]) -> [Int: BridgeStatistics] {
    var bridgeStats: [Int: BridgeStatistics] = [:]

    let bridgeGroups = Dictionary(grouping: features) { $0.bridge_id }

    for (bridgeID, bridgeFeatures) in bridgeGroups {
      let recordCount = bridgeFeatures.count

      // For features, we don't have direct timestamps
      let firstTimestamp = Date()
      let lastTimestamp = Date()

      let countsByMinute: [String: Int] = [:]  // Placeholder
      let countsByHour: [Int: Int] = [:]  // Placeholder
      let countsByDayOfWeek: [Int: Int] = [:]  // Placeholder

      let completenessPercentage = calculateBridgeCompleteness(from: bridgeFeatures)

      bridgeStats[bridgeID] = BridgeStatistics(
        bridgeID: bridgeID,
        recordCount: recordCount,
        firstTimestamp: firstTimestamp,
        lastTimestamp: lastTimestamp,
        countsByMinute: countsByMinute,
        countsByHour: countsByHour,
        countsByDayOfWeek: countsByDayOfWeek,
        completenessPercentage: completenessPercentage)
    }

    return bridgeStats
  }

  private func generateTimeStatistics(from ticks: [ProbeTickRaw]) -> TimeStatistics {
    let countsByMinute = calculateCountsByMinute(from: ticks)
    let countsByHour = calculateCountsByHour(from: ticks)
    let countsByDayOfWeek = calculateCountsByDayOfWeek(from: ticks)

    let peakActivityTimes = findPeakActivityTimes(from: countsByHour)
    let lowActivityTimes = findLowActivityTimes(from: countsByHour)

    return TimeStatistics(
      countsByMinute: countsByMinute,
      countsByHour: countsByHour,
      countsByDayOfWeek: countsByDayOfWeek,
      peakActivityTimes: peakActivityTimes,
      lowActivityTimes: lowActivityTimes)
  }

  private func generateTimeStatistics(from _: [FeatureVector]) -> TimeStatistics {
    // For features, we don't have direct timestamps, so we'll use placeholders
    let countsByMinute: [String: Int] = [:]
    let countsByHour: [Int: Int] = [:]
    let countsByDayOfWeek: [Int: Int] = [:]
    let peakActivityTimes: [String: Int] = [:]
    let lowActivityTimes: [String: Int] = [:]

    return TimeStatistics(
      countsByMinute: countsByMinute,
      countsByHour: countsByHour,
      countsByDayOfWeek: countsByDayOfWeek,
      peakActivityTimes: peakActivityTimes,
      lowActivityTimes: lowActivityTimes)
  }

  private func generateHorizonStatistics(from ticks: [ProbeTickRaw]) -> HorizonStatistics {
    // For ticks, we need to extract horizon information from the data structure
    // This is a placeholder implementation - you'll need to adapt based on your actual data
    let availableHorizons = detectAvailableHorizons(from: ticks)
    let coverageByHorizon = calculateCoverageByHorizon(from: ticks, horizons: availableHorizons)
    let bridgeCoverageByHorizon = calculateBridgeCoverageByHorizon(
      from: ticks, horizons: availableHorizons)
    let missingHorizonsByBridge = calculateMissingHorizonsByBridge(
      from: ticks, horizons: availableHorizons)
    let horizonGaps = detectHorizonGaps(in: availableHorizons)
    let overallCompleteness = calculateOverallHorizonCompleteness(
      from: ticks, horizons: availableHorizons)

    return HorizonStatistics(
      availableHorizons: availableHorizons,
      coverageByHorizon: coverageByHorizon,
      bridgeCoverageByHorizon: bridgeCoverageByHorizon,
      missingHorizonsByBridge: missingHorizonsByBridge,
      horizonGaps: horizonGaps,
      overallCompleteness: overallCompleteness)
  }

  private func generateHorizonStatistics(from features: [FeatureVector]) -> HorizonStatistics {
    let availableHorizons = Set(features.map { $0.horizon_min }).sorted()
    let coverageByHorizon = calculateCoverageByHorizon(from: features, horizons: availableHorizons)
    let bridgeCoverageByHorizon = calculateBridgeCoverageByHorizon(
      from: features, horizons: availableHorizons)
    let missingHorizonsByBridge = calculateMissingHorizonsByBridge(
      from: features, horizons: availableHorizons)
    let horizonGaps = detectHorizonGaps(in: availableHorizons)
    let overallCompleteness = calculateOverallHorizonCompleteness(
      from: features, horizons: availableHorizons)

    return HorizonStatistics(
      availableHorizons: availableHorizons,
      coverageByHorizon: coverageByHorizon,
      bridgeCoverageByHorizon: bridgeCoverageByHorizon,
      missingHorizonsByBridge: missingHorizonsByBridge,
      horizonGaps: horizonGaps,
      overallCompleteness: overallCompleteness)
  }

  private func generateQualityMetrics(from ticks: [ProbeTickRaw]) -> DataQualityMetrics {
    let dataCompleteness = calculateDataCompleteness(from: ticks)
    let timestampValidity = calculateTimestampValidity(from: ticks)
    let bridgeIDValidity = calculateBridgeIDValidity(from: ticks)
    let speedDataValidity = calculateSpeedDataValidity(from: ticks)
    let duplicateCount = calculateDuplicateCount(from: ticks)
    let missingFieldsCount = calculateMissingFieldsCount(from: ticks)

    return DataQualityMetrics(
      dataCompleteness: dataCompleteness,
      timestampValidity: timestampValidity,
      bridgeIDValidity: bridgeIDValidity,
      speedDataValidity: speedDataValidity,
      duplicateCount: duplicateCount,
      missingFieldsCount: missingFieldsCount)
  }

  private func generateQualityMetrics(from features: [FeatureVector]) -> DataQualityMetrics {
    let dataCompleteness = calculateDataCompleteness(from: features)
    let timestampValidity = 1.0  // Features don't have timestamps
    let bridgeIDValidity = calculateBridgeIDValidity(from: features)
    let speedDataValidity = calculateSpeedDataValidity(from: features)
    let duplicateCount = calculateDuplicateCount(from: features)
    let missingFieldsCount = calculateMissingFieldsCount(from: features)

    return DataQualityMetrics(
      dataCompleteness: dataCompleteness,
      timestampValidity: timestampValidity,
      bridgeIDValidity: bridgeIDValidity,
      speedDataValidity: speedDataValidity,
      duplicateCount: duplicateCount,
      missingFieldsCount: missingFieldsCount)
  }

  // MARK: - Helper Methods

  private func calculateCountsByMinute(from ticks: [ProbeTickRaw]) -> [String: Int] {
    var counts: [String: Int] = [:]

    for tick in ticks {
      guard let date = ISO8601DateFormatter().date(from: tick.ts_utc) else { continue }
      let calendar = Calendar.current
      let hour = calendar.component(.hour, from: date)
      let minute = calendar.component(.minute, from: date)
      let key = String(format: "%02d:%02d", hour, minute)
      counts[key, default: 0] += 1
    }

    return counts
  }

  private func calculateCountsByHour(from ticks: [ProbeTickRaw]) -> [Int: Int] {
    var counts: [Int: Int] = [:]

    for tick in ticks {
      guard let date = ISO8601DateFormatter().date(from: tick.ts_utc) else { continue }
      let calendar = Calendar.current
      let hour = calendar.component(.hour, from: date)
      counts[hour, default: 0] += 1
    }

    return counts
  }

  private func calculateCountsByDayOfWeek(from ticks: [ProbeTickRaw]) -> [Int: Int] {
    var counts: [Int: Int] = [:]

    for tick in ticks {
      guard let date = ISO8601DateFormatter().date(from: tick.ts_utc) else { continue }
      let calendar = Calendar.current
      let dayOfWeek = calendar.component(.weekday, from: date) - 1  // 0 = Sunday
      counts[dayOfWeek, default: 0] += 1
    }

    return counts
  }

  private func findPeakActivityTimes(from countsByHour: [Int: Int]) -> [String: Int] {
    let sorted = countsByHour.sorted { $0.value > $1.value }
    let top3 = Array(sorted.prefix(3))
    return Dictionary(
      uniqueKeysWithValues: top3.map { (String(format: "%02d:00", $0.key), $0.value) })
  }

  private func findLowActivityTimes(from countsByHour: [Int: Int]) -> [String: Int] {
    let sorted = countsByHour.sorted { $0.value < $1.value }
    let bottom3 = Array(sorted.prefix(3))
    return Dictionary(
      uniqueKeysWithValues: bottom3.map { (String(format: "%02d:00", $0.key), $0.value) })
  }

  private func detectAvailableHorizons(from _: [ProbeTickRaw]) -> [Int] {
    // This is a placeholder - you'll need to implement based on your actual data structure
    return [0, 3, 6, 9, 12]
  }

  private func calculateCoverageByHorizon(from _: [ProbeTickRaw], horizons: [Int]) -> [Int: Double]
  {
    // Placeholder implementation
    var coverage: [Int: Double] = [:]
    for horizon in horizons {
      coverage[horizon] = 0.8  // Placeholder value
    }
    return coverage
  }

  private func calculateCoverageByHorizon(from features: [FeatureVector], horizons: [Int]) -> [Int:
    Double]
  {
    var coverage: [Int: Double] = [:]

    for horizon in horizons {
      let horizonFeatures = features.filter { $0.horizon_min == horizon }
      let coveragePercentage = Double(horizonFeatures.count) / Double(features.count)
      coverage[horizon] = coveragePercentage
    }

    return coverage
  }

  private func calculateBridgeCoverageByHorizon(from _: [ProbeTickRaw], horizons _: [Int]) -> [Int:
    [Int: Double]]
  {
    // Placeholder implementation
    return [:]
  }

  private func calculateBridgeCoverageByHorizon(from features: [FeatureVector], horizons: [Int])
    -> [Int: [Int: Double]]
  {
    var bridgeCoverage: [Int: [Int: Double]] = [:]
    let bridgeGroups = Dictionary(grouping: features) { $0.bridge_id }

    for (bridgeID, bridgeFeatures) in bridgeGroups {
      var horizonCoverage: [Int: Double] = [:]

      for horizon in horizons {
        let horizonFeatures = bridgeFeatures.filter { $0.horizon_min == horizon }
        let coveragePercentage = Double(horizonFeatures.count) / Double(bridgeFeatures.count)
        horizonCoverage[horizon] = coveragePercentage
      }

      bridgeCoverage[bridgeID] = horizonCoverage
    }

    return bridgeCoverage
  }

  private func calculateMissingHorizonsByBridge(from _: [ProbeTickRaw], horizons _: [Int]) -> [Int:
    [Int]]
  {
    // Placeholder implementation
    return [:]
  }

  private func calculateMissingHorizonsByBridge(from features: [FeatureVector], horizons: [Int])
    -> [Int: [Int]]
  {
    var missingHorizons: [Int: [Int]] = [:]
    let bridgeGroups = Dictionary(grouping: features) { $0.bridge_id }

    for (bridgeID, bridgeFeatures) in bridgeGroups {
      let bridgeHorizons = Set(bridgeFeatures.map { $0.horizon_min })
      let missing = horizons.filter { !bridgeHorizons.contains($0) }
      missingHorizons[bridgeID] = missing
    }

    return missingHorizons
  }

  private func detectHorizonGaps(in horizons: [Int]) -> [Int: [Int]] {
    var gaps: [Int: [Int]] = [:]

    for i in 0..<(horizons.count - 1) {
      let current = horizons[i]
      let next = horizons[i + 1]
      let expectedNext = current + 3  // Assuming 3-minute intervals

      if next != expectedNext {
        var missing: [Int] = []
        for missingHorizon in stride(from: expectedNext, to: next, by: 3) {
          missing.append(missingHorizon)
        }
        gaps[current] = missing
      }
    }

    return gaps
  }

  private func calculateOverallHorizonCompleteness(from _: [ProbeTickRaw], horizons _: [Int])
    -> Double
  {
    // Placeholder implementation
    return 0.85
  }

  private func calculateOverallHorizonCompleteness(from features: [FeatureVector], horizons: [Int])
    -> Double
  {
    let totalExpected = features.count * horizons.count
    let totalCovered = features.count

    return totalExpected > 0 ? Double(totalCovered) / Double(totalExpected) : 0.0
  }

  private func calculateCompleteness(from ticks: [ProbeTickRaw]) -> Double {
    let validTicks = ticks.filter { tick in
      !tick.ts_utc.isEmpty && tick.bridge_id > 0
        && ISO8601DateFormatter().date(from: tick.ts_utc) != nil
    }

    return ticks.count > 0 ? Double(validTicks.count) / Double(ticks.count) : 0.0
  }

  private func calculateCompleteness(from features: [FeatureVector]) -> Double {
    let validFeatures = features.filter { feature in
      feature.bridge_id > 0 && feature.horizon_min >= 0
    }

    return features.count > 0 ? Double(validFeatures.count) / Double(features.count) : 0.0
  }

  private func calculateBridgeCompleteness(from ticks: [ProbeTickRaw]) -> Double {
    return calculateCompleteness(from: ticks)
  }

  private func calculateBridgeCompleteness(from features: [FeatureVector]) -> Double {
    return calculateCompleteness(from: features)
  }

  private func calculateDataCompleteness(from ticks: [ProbeTickRaw]) -> Double {
    let completeTicks = ticks.filter { tick in
      !tick.ts_utc.isEmpty && tick.bridge_id > 0 && tick.open_label >= 0
    }

    return ticks.count > 0 ? Double(completeTicks.count) / Double(ticks.count) : 0.0
  }

  private func calculateDataCompleteness(from features: [FeatureVector]) -> Double {
    let completeFeatures = features.filter { feature in
      feature.bridge_id > 0 && feature.horizon_min >= 0 && feature.target >= 0
    }

    return features.count > 0 ? Double(completeFeatures.count) / Double(features.count) : 0.0
  }

  private func calculateTimestampValidity(from ticks: [ProbeTickRaw]) -> Double {
    let validTimestamps = ticks.filter { tick in
      ISO8601DateFormatter().date(from: tick.ts_utc) != nil
    }

    return ticks.count > 0 ? Double(validTimestamps.count) / Double(ticks.count) : 0.0
  }

  private func calculateBridgeIDValidity(from ticks: [ProbeTickRaw]) -> Double {
    let validBridgeIDs = ticks.filter { tick in
      tick.bridge_id > 0
    }

    return ticks.count > 0 ? Double(validBridgeIDs.count) / Double(ticks.count) : 0.0
  }

  private func calculateBridgeIDValidity(from features: [FeatureVector]) -> Double {
    let validBridgeIDs = features.filter { feature in
      feature.bridge_id > 0
    }

    return features.count > 0 ? Double(validBridgeIDs.count) / Double(features.count) : 0.0
  }

  private func calculateSpeedDataValidity(from ticks: [ProbeTickRaw]) -> Double {
    let validSpeedData = ticks.filter { tick in
      tick.current_traffic_speed != nil || tick.normal_traffic_speed != nil
    }

    return ticks.count > 0 ? Double(validSpeedData.count) / Double(ticks.count) : 0.0
  }

  private func calculateSpeedDataValidity(from features: [FeatureVector]) -> Double {
    let validSpeedData = features.filter { feature in
      feature.current_speed > 0 && feature.normal_speed > 0
    }

    return features.count > 0 ? Double(validSpeedData.count) / Double(features.count) : 0.0
  }

  private func calculateDuplicateCount(from ticks: [ProbeTickRaw]) -> Int {
    let uniqueTicks = Set(ticks.map { "\($0.bridge_id)_\($0.ts_utc)" })
    return ticks.count - uniqueTicks.count
  }

  private func calculateDuplicateCount(from features: [FeatureVector]) -> Int {
    let uniqueFeatures = Set(features.map { "\($0.bridge_id)_\($0.horizon_min)" })
    return features.count - uniqueFeatures.count
  }

  private func calculateMissingFieldsCount(from ticks: [ProbeTickRaw]) -> Int {
    return ticks.filter { tick in
      tick.ts_utc.isEmpty || tick.bridge_id <= 0
    }.count
  }

  private func calculateMissingFieldsCount(from features: [FeatureVector]) -> Int {
    return features.filter { feature in
      feature.bridge_id <= 0 || feature.horizon_min < 0
    }.count
  }
}

// MARK: - Statistics Export

extension DataStatisticsService {
  /// Exports statistics to JSON format
  /// - Parameter statistics: The statistics to export
  /// - Returns: JSON string representation
  public func exportToJSON(_ statistics: BridgeDataStatistics) throws -> String {
    let encoder = JSONEncoder.bridgeEncoder(outputFormatting: [.prettyPrinted, .sortedKeys])

    let data = try encoder.encode(statistics)
    return String(data: data, encoding: .utf8) ?? ""
  }

  /// Exports statistics to CSV format
  /// - Parameter statistics: The statistics to export
  /// - Returns: CSV string representation
  public func exportToCSV(_ statistics: BridgeDataStatistics) -> String {
    var csv = "Bridge ID,Record Count,First Timestamp,Last Timestamp,Completeness %\n"

    for (bridgeID, bridgeStat) in statistics.bridgeStats.sorted(by: { $0.key < $1.key }) {
      let row =
        "\(bridgeID),\(bridgeStat.recordCount),\(bridgeStat.firstTimestamp),\(bridgeStat.lastTimestamp),\(String(format: "%.2f", bridgeStat.completenessPercentage * 100))\n"
      csv += row
    }

    return csv
  }

  /// Exports horizon coverage to CSV format
  /// - Parameter statistics: The statistics to export
  /// - Returns: CSV string representation of horizon coverage
  public func exportHorizonCoverageToCSV(_ statistics: BridgeDataStatistics) -> String {
    var csv = "Bridge ID"

    // Add horizon headers
    for horizon in statistics.horizonStats.availableHorizons {
      csv += ",Horizon \(horizon)min"
    }
    csv += "\n"

    // Add data rows
    for (bridgeID, _) in statistics.bridgeStats.sorted(by: { $0.key < $1.key }) {
      csv += "\(bridgeID)"

      for horizon in statistics.horizonStats.availableHorizons {
        let coverage = statistics.horizonStats.bridgeCoverageByHorizon[bridgeID]?[horizon] ?? 0.0
        csv += ",\(String(format: "%.2f", coverage * 100))"
      }
      csv += "\n"
    }

    return csv
  }
}
