//
//  HistoricalBridgeDataProvider.swift
//  Bridget
//
//  Multi-Path Probability Traffic Prediction System
//  Purpose: Provide historical bridge opening data for baseline prediction and ML training
//  Integration: Used by BaselinePredictor and ML model training pipeline
//  Acceptance: 5-minute bucket alignment, Beta smoothing support, fallback behavior
//  Known Limits: File-based storage, 5-minute granularity, bridge-specific data
//

import Foundation

// MARK: - Data Structures

/// Represents a 5-minute time bucket for historical data alignment
public struct DateBucket: Codable, Hashable, Equatable {
  public let hour: Int  // 0-23
  public let minute: Int  // 0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55
  public let isWeekend: Bool

  public init(hour: Int, minute: Int, isWeekend: Bool) {
    self.hour = max(0, min(23, hour))
    self.minute = (minute / 5) * 5  // Round to nearest 5-minute bucket
    self.isWeekend = isWeekend
  }

  public init(from date: Date) {
    let calendar = Calendar.current
    let components = calendar.dateComponents([.hour, .minute, .weekday], from: date)

    self.hour = components.hour ?? 0
    self.minute = ((components.minute ?? 0) / 5) * 5
    self.isWeekend = (components.weekday == 1 || components.weekday == 7)  // Sunday = 1, Saturday = 7
  }

  /// Convert to bucket index for efficient storage (0-287 for weekday, 288-575 for weekend)
  public var bucketIndex: Int {
    let baseIndex = hour * 12 + (minute / 5)
    return isWeekend ? baseIndex + 288 : baseIndex
  }

  /// Create from bucket index
  public static func from(bucketIndex: Int) -> DateBucket {
    let isWeekend = bucketIndex >= 288
    let adjustedIndex = isWeekend ? bucketIndex - 288 : bucketIndex
    let hour = adjustedIndex / 12
    let minute = (adjustedIndex % 12) * 5
    return DateBucket(hour: hour, minute: minute, isWeekend: isWeekend)
  }

  // MARK: - Hashable

  public func hash(into hasher: inout Hasher) {
    hasher.combine(bucketIndex)
  }

  public static func == (lhs: DateBucket, rhs: DateBucket) -> Bool {
    return lhs.bucketIndex == rhs.bucketIndex
  }
}

/// Historical opening statistics for a bridge in a specific time bucket
public struct BridgeOpeningStats: Codable, Equatable {
  public let openCount: Int
  public let totalCount: Int
  public let lastSeen: Date?
  public let sampleCount: Int

  public init(openCount: Int, totalCount: Int, lastSeen: Date? = nil, sampleCount: Int = 0) {
    self.openCount = openCount
    self.totalCount = totalCount
    self.lastSeen = lastSeen
    self.sampleCount = sampleCount
  }

  /// Raw opening probability (0.0 - 1.0)
  public var rawProbability: Double {
    guard totalCount > 0 else { return 0.0 }
    return Double(openCount) / Double(totalCount)
  }

  /// Beta-smoothed probability with given alpha/beta parameters
  public func smoothedProbability(alpha: Double, beta: Double) -> Double {
    let numerator = Double(openCount) + alpha
    let denominator = Double(totalCount) + alpha + beta
    return numerator / denominator
  }

  /// Whether this bucket has sufficient data for reliable prediction
  public var hasSufficientData: Bool {
    return sampleCount >= 10  // At least 10 samples for reliability
  }
}

/// Historical data for a specific bridge across all time buckets
public struct BridgeHistoricalData: Codable, Equatable {
  public let bridgeID: String
  public let bucketStats: [DateBucket: BridgeOpeningStats]
  public let lastUpdated: Date

  public init(
    bridgeID: String, bucketStats: [DateBucket: BridgeOpeningStats], lastUpdated: Date = Date()
  ) {
    self.bridgeID = bridgeID
    self.bucketStats = bucketStats
    self.lastUpdated = lastUpdated
  }

  /// Get stats for a specific time bucket
  public func stats(for bucket: DateBucket) -> BridgeOpeningStats? {
    return bucketStats[bucket]
  }

  /// Get all buckets that have data
  public var bucketsWithData: [DateBucket] {
    return Array(bucketStats.keys)
  }

  /// Total number of samples across all buckets
  public var totalSamples: Int {
    return bucketStats.values.reduce(0) { $0 + $1.sampleCount }
  }
}

// MARK: - Protocol Definition

/// Protocol for providing historical bridge opening data
/// Used by BaselinePredictor and ML training pipeline
public protocol HistoricalBridgeDataProvider {
  /// Get opening statistics for a bridge in a specific time bucket
  /// - Parameters:
  ///   - bridgeID: The bridge identifier
  ///   - bucket: The 5-minute time bucket
  /// - Returns: Opening statistics if available, nil otherwise
  func getOpeningStats(bridgeID: String, bucket: DateBucket) -> BridgeOpeningStats?

  /// Get opening statistics for a bridge across multiple time buckets
  /// - Parameters:
  ///   - bridgeID: The bridge identifier
  ///   - buckets: Array of time buckets
  /// - Returns: Dictionary mapping buckets to statistics
  func getOpeningStats(bridgeID: String, buckets: [DateBucket]) -> [DateBucket: BridgeOpeningStats]

  /// Get all available bridge IDs
  /// - Returns: Array of bridge IDs that have historical data
  func getAvailableBridgeIDs() -> [String]

  /// Get complete historical data for a bridge
  /// - Parameter bridgeID: The bridge identifier
  /// - Returns: Complete historical data if available, nil otherwise
  func getHistoricalData(for bridgeID: String) -> BridgeHistoricalData?

  /// Check if a bridge has historical data
  /// - Parameter bridgeID: The bridge identifier
  /// - Returns: True if historical data is available
  func hasData(for bridgeID: String) -> Bool

  /// Get the last update time for a bridge's data
  /// - Parameter bridgeID: The bridge identifier
  /// - Returns: Last update time if available, nil otherwise
  func getLastUpdated(for bridgeID: String) -> Date?
}

// MARK: - File-Based Implementation

/// File-based implementation of HistoricalBridgeDataProvider
/// Stores data in JSON files for persistence and easy inspection
public class FileBasedHistoricalBridgeDataProvider: HistoricalBridgeDataProvider {
  private let dataDirectory: URL
  private let fileManager: FileManager
  private var cache: [String: BridgeHistoricalData] = [:]
  private let cacheQueue = DispatchQueue(
    label: "com.bridget.historicaldata.cache", attributes: .concurrent)

  public init(dataDirectory: URL) {
    self.dataDirectory = dataDirectory
    self.fileManager = FileManager.default

    // Create directory if it doesn't exist
    try? fileManager.createDirectory(at: dataDirectory, withIntermediateDirectories: true)
  }

  // MARK: - HistoricalBridgeDataProvider Implementation

  public func getOpeningStats(bridgeID: String, bucket: DateBucket) -> BridgeOpeningStats? {
    return cacheQueue.sync {
      if let data = cache[bridgeID] {
        return data.stats(for: bucket)
      }

      // Load from file if not in cache
      if let data = loadHistoricalData(for: bridgeID) {
        cache[bridgeID] = data
        return data.stats(for: bucket)
      }

      return nil
    }
  }

  public func getOpeningStats(bridgeID: String, buckets: [DateBucket]) -> [DateBucket:
    BridgeOpeningStats]
  {
    return cacheQueue.sync {
      if let data = cache[bridgeID] {
        var result: [DateBucket: BridgeOpeningStats] = [:]
        for bucket in buckets {
          if let stats = data.stats(for: bucket) {
            result[bucket] = stats
          }
        }
        return result
      }

      // Load from file if not in cache
      if let data = loadHistoricalData(for: bridgeID) {
        cache[bridgeID] = data
        var result: [DateBucket: BridgeOpeningStats] = [:]
        for bucket in buckets {
          if let stats = data.stats(for: bucket) {
            result[bucket] = stats
          }
        }
        return result
      }

      return [:]
    }
  }

  public func getAvailableBridgeIDs() -> [String] {
    return cacheQueue.sync {
      do {
        let files = try fileManager.contentsOfDirectory(
          at: dataDirectory, includingPropertiesForKeys: nil)
        return files.compactMap { url in
          let filename = url.lastPathComponent
          if filename.hasSuffix(".json") {
            return String(filename.dropLast(5))  // Remove .json extension
          }
          return nil
        }
      } catch {
        print("Error reading available bridge IDs: \(error)")
        return []
      }
    }
  }

  public func getHistoricalData(for bridgeID: String) -> BridgeHistoricalData? {
    return cacheQueue.sync {
      if let data = cache[bridgeID] {
        return data
      }

      // Load from file
      if let data = loadHistoricalData(for: bridgeID) {
        cache[bridgeID] = data
        return data
      }

      return nil
    }
  }

  public func hasData(for bridgeID: String) -> Bool {
    return cacheQueue.sync {
      if cache[bridgeID] != nil {
        return true
      }

      let fileURL = dataDirectory.appendingPathComponent("\(bridgeID).json")
      return fileManager.fileExists(atPath: fileURL.path)
    }
  }

  public func getLastUpdated(for bridgeID: String) -> Date? {
    return cacheQueue.sync {
      if let data = cache[bridgeID] {
        return data.lastUpdated
      }

      if let data = loadHistoricalData(for: bridgeID) {
        cache[bridgeID] = data
        return data.lastUpdated
      }

      return nil
    }
  }

  // MARK: - Data Management

  /// Save historical data for a bridge
  /// - Parameter data: The historical data to save
  /// - Throws: Error if saving fails
  public func saveHistoricalData(_ data: BridgeHistoricalData) throws {
    let fileURL = dataDirectory.appendingPathComponent("\(data.bridgeID).json")
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    encoder.outputFormatting = .prettyPrinted

    let jsonData = try encoder.encode(data)
    try jsonData.write(to: fileURL)

    cacheQueue.async(flags: .barrier) {
      self.cache[data.bridgeID] = data
    }
  }

  /// Update opening statistics for a bridge in a specific bucket
  /// - Parameters:
  ///   - bridgeID: The bridge identifier
  ///   - bucket: The time bucket
  ///   - wasOpen: Whether the bridge was open
  ///   - timestamp: When this observation occurred
  /// - Throws: Error if saving fails
  public func updateOpeningStats(
    bridgeID: String, bucket: DateBucket, wasOpen: Bool, timestamp: Date
  ) throws {
    let data =
      getHistoricalData(for: bridgeID) ?? BridgeHistoricalData(bridgeID: bridgeID, bucketStats: [:])

    let stats = data.bucketStats[bucket] ?? BridgeOpeningStats(openCount: 0, totalCount: 0)

    // Update statistics
    let newOpenCount = stats.openCount + (wasOpen ? 1 : 0)
    let newTotalCount = stats.totalCount + 1
    let newLastSeen = timestamp > (stats.lastSeen ?? Date.distantPast) ? timestamp : stats.lastSeen
    let newSampleCount = stats.sampleCount + 1

    let updatedStats = BridgeOpeningStats(
      openCount: newOpenCount,
      totalCount: newTotalCount,
      lastSeen: newLastSeen,
      sampleCount: newSampleCount)

    var updatedBucketStats = data.bucketStats
    updatedBucketStats[bucket] = updatedStats

    let updatedData = BridgeHistoricalData(
      bridgeID: bridgeID,
      bucketStats: updatedBucketStats,
      lastUpdated: Date())

    try saveHistoricalData(updatedData)
  }

  /// Clear cache for a specific bridge
  /// - Parameter bridgeID: The bridge identifier
  public func clearCache(for bridgeID: String) {
    cacheQueue.async(flags: .barrier) {
      self.cache.removeValue(forKey: bridgeID)
    }
  }

  /// Clear entire cache
  public func clearCache() {
    cacheQueue.async(flags: .barrier) {
      self.cache.removeAll()
    }
  }

  // MARK: - Private Methods

  private func loadHistoricalData(for bridgeID: String) -> BridgeHistoricalData? {
    let fileURL = dataDirectory.appendingPathComponent("\(bridgeID).json")

    guard fileManager.fileExists(atPath: fileURL.path) else {
      return nil
    }

    do {
      let jsonData = try Data(contentsOf: fileURL)
      let decoder = JSONDecoder()
      decoder.dateDecodingStrategy = .iso8601

      return try decoder.decode(BridgeHistoricalData.self, from: jsonData)
    } catch {
      print("Error loading historical data for bridge \(bridgeID): \(error)")
      return nil
    }
  }
}

// MARK: - Mock Implementation for Testing

/// Mock implementation for testing and development
public class MockHistoricalBridgeDataProvider: HistoricalBridgeDataProvider {
  private var mockData: [String: BridgeHistoricalData] = [:]

  public init() {}

  public func setMockData(_ data: BridgeHistoricalData) {
    mockData[data.bridgeID] = data
  }

  public func setMockStats(bridgeID: String, bucket: DateBucket, stats: BridgeOpeningStats) {
    var data = mockData[bridgeID] ?? BridgeHistoricalData(bridgeID: bridgeID, bucketStats: [:])
    var bucketStats = data.bucketStats
    bucketStats[bucket] = stats
    data = BridgeHistoricalData(bridgeID: bridgeID, bucketStats: bucketStats, lastUpdated: Date())
    mockData[bridgeID] = data
  }

  // MARK: - HistoricalBridgeDataProvider Implementation

  public func getOpeningStats(bridgeID: String, bucket: DateBucket) -> BridgeOpeningStats? {
    return mockData[bridgeID]?.stats(for: bucket)
  }

  public func getOpeningStats(bridgeID: String, buckets: [DateBucket]) -> [DateBucket:
    BridgeOpeningStats]
  {
    guard let data = mockData[bridgeID] else { return [:] }

    var result: [DateBucket: BridgeOpeningStats] = [:]
    for bucket in buckets {
      if let stats = data.stats(for: bucket) {
        result[bucket] = stats
      }
    }
    return result
  }

  public func getAvailableBridgeIDs() -> [String] {
    return Array(mockData.keys)
  }

  public func getHistoricalData(for bridgeID: String) -> BridgeHistoricalData? {
    return mockData[bridgeID]
  }

  public func hasData(for bridgeID: String) -> Bool {
    return mockData[bridgeID] != nil
  }

  public func getLastUpdated(for bridgeID: String) -> Date? {
    return mockData[bridgeID]?.lastUpdated
  }
}
