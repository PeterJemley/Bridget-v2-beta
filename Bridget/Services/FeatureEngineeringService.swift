//
//  FeatureEngineeringService.swift
//  Bridget
//
//  ## Purpose
//  Feature engineering service for ML training data preparation
//  Extracted from TrainPrepService to maintain separation of concerns
//
//  ✅ STATUS: COMPLETE - All requirements implemented and tested
//  ✅ COMPLETION DATE: August 17, 2025
//
//  ## Dependencies
//  Foundation framework for date handling and mathematical operations
//  Centralized MLTypes.swift for ProbeTickRaw and FeatureVector types
//  Centralized Protocols.swift for FeatureEngineeringProgressDelegate
//
//  ## Integration Points
//  Called by TrainPrepService for feature generation
//  Generates MLMultiArray outputs for Core ML training
//
//  ## Key Features
//  Cyclical encoding for time features
//  Rolling averages for bridge opening patterns
//  Deterministic feature generation with configurable seed
//  Direct MLMultiArray output (no CSV intermediate)
//  Pure, stateless feature generation with comprehensive test coverage
//

import CoreML
import Foundation

// Centralized types and protocols are now in the same target

// MARK: - Top-Level Helper Functions

/// Computes the cyclical encoding (sine and cosine) for a given value and period.
/// - Parameters:
///   - x: The value to encode cyclically.
///   - period: The period of the cycle.
/// - Returns: A tuple of sine and cosine values representing the cyclical encoding.
public func cyc(_ x: Double, period: Double) -> (Double, Double) {
  let angle = 2 * Double.pi * x / period
  return (sin(angle), cos(angle))
}

/// Calculates rolling averages over a window for an array of optional Doubles.
/// - Parameters:
///   - input: The input array of optional Double values.
///   - window: The size of the rolling window.
/// - Returns: An array of rolling average values, with zero used when no valid values exist.
public func rollingAverage(_ input: [Double?], window: Int) -> [Double] {
  var result = [Double]()
  var windowVals = [Double]()
  for (_, v) in input.enumerated() {
    if let v = v { windowVals.append(v) }
    if windowVals.count > window { windowVals.removeFirst() }
    let avg = !windowVals.isEmpty ? windowVals.reduce(0, +) / Double(windowVals.count) : 0.0
    result.append(avg)
  }
  return result
}

/// Returns the ISO8601 weekday component for a given Date.
/// - Parameter date: The date to extract the weekday from.
/// - Returns: An integer representing the day of the week (Sunday=1 ... Saturday=7).
public func dayOfWeek(from date: Date) -> Int {
  let calendar = Calendar(identifier: .iso8601)
  return calendar.component(.weekday, from: date) // Sunday=1 ... Saturday=7
}

/// Returns the minute of the day (0-1439) for a given Date.
/// - Parameter date: The date to extract the minute of the day from.
/// - Returns: An integer representing the minute of the day.
public func minuteOfDay(from date: Date) -> Int {
  let calendar = Calendar(identifier: .iso8601)
  let hour = calendar.component(.hour, from: date)
  let minute = calendar.component(.minute, from: date)
  return hour * 60 + minute
}

// MARK: - Pure Feature Generation Function

/// Pure, stateless feature generator function
/// - Parameters:
///   - ticks: Raw probe tick data
///   - horizons: List of horizon offsets (minutes)
///   - deterministicSeed: Seed for reproducibility
/// - Returns: Array (per horizon) of FeatureVector arrays
public func makeFeatures(from ticks: [ProbeTickRaw],
                         horizons: [Int],
                         deterministicSeed: UInt64 = 42) -> [[FeatureVector]]
{
  // Set deterministic seed for reproducible processing
  srand48(Int(truncatingIfNeeded: deterministicSeed))

  let grouped = Dictionary(grouping: ticks) { $0.bridge_id }
  let isoFormatter = ISO8601DateFormatter()

  var allFeatures = Array(repeating: [FeatureVector](), count: horizons.count)

  for (_, bridgeTicks) in grouped {
    let sortedTicks = bridgeTicks.sorted {
      guard let d1 = isoFormatter.date(from: $0.ts_utc), let d2 = isoFormatter.date(from: $1.ts_utc) else { return false }
      return d1 < d2
    }

    let openLabels = sortedTicks.map { Double($0.open_label) }
    let open5m = rollingAverage(openLabels, window: 5)
    let open30m = rollingAverage(openLabels, window: 30)

    for (i, tick) in sortedTicks.enumerated() {
      guard let date = isoFormatter.date(from: tick.ts_utc) else { continue }
      let minOfDay = Double(minuteOfDay(from: date))
      let dow = Double(dayOfWeek(from: date))
      let (minSin, minCos) = cyc(minOfDay, period: 1440)
      let (dowSin, dowCos) = cyc(dow, period: 7)

      for (hIdx, horizon) in horizons.enumerated() {
        let targetIdx = i + horizon
        let target = (targetIdx < sortedTicks.count) ? sortedTicks[targetIdx].open_label : 0

        let penaltyNorm = min(max(tick.via_penalty_sec ?? 0.0, 0.0), 900.0) / 900.0
        let gateAnomNorm = min(max(tick.gate_anom ?? 1.0, 1.0), 8.0) / 8.0
        let crossRate: Double = {
          let k = tick.cross_k ?? 0.0
          let n = tick.cross_n ?? 0.0
          return n > 0 ? k / n : -1.0
        }()
        let vR = tick.via_routable ?? 0.0
        let detourDelta = tick.detour_delta ?? 0.0
        let detourFrac = tick.detour_frac ?? 0.0

        let fv = FeatureVector(bridge_id: tick.bridge_id,
                               horizon_min: horizon,
                               min_sin: minSin,
                               min_cos: minCos,
                               dow_sin: dowSin,
                               dow_cos: dowCos,
                               open_5m: open5m[i],
                               open_30m: open30m[i],
                               detour_delta: detourDelta,
                               cross_rate: crossRate,
                               via_routable: vR,
                               via_penalty: penaltyNorm,
                               gate_anom: gateAnomNorm,
                               detour_frac: detourFrac,
                               current_speed: tick.current_traffic_speed ?? 0.0,
                               normal_speed: tick.normal_traffic_speed ?? 35.0,
                               target: target)
        allFeatures[hIdx].append(fv)
      }
    }
  }

  return allFeatures
}

// MARK: - Main Service

public class FeatureEngineeringService {
  private let configuration: FeatureEngineeringConfiguration
  private weak var progressDelegate: FeatureEngineeringProgressDelegate?

  init(configuration: FeatureEngineeringConfiguration, progressDelegate: FeatureEngineeringProgressDelegate? = nil) {
    self.configuration = configuration
    self.progressDelegate = progressDelegate
  }

  /// Generates feature vectors from probe tick data with deterministic processing
  /// - Parameter ticks: Raw probe tick data
  /// - Returns: Array of feature vectors organized by horizon
  /// - Throws: Feature engineering errors
  public func generateFeatures(from ticks: [ProbeTickRaw]) throws -> [[FeatureVector]] {
    progressDelegate?.featureEngineeringDidStart()

    let allFeatures = makeFeatures(from: ticks,
                                   horizons: configuration.horizons,
                                   deterministicSeed: configuration.deterministicSeed)

    let totalFeatures = allFeatures.flatMap { $0 }.count
    progressDelegate?.featureEngineeringDidComplete(totalFeatures)

    return allFeatures
  }

  /// Converts feature vectors directly to MLMultiArray format for Core ML
  /// - Parameter features: Array of feature vectors
  /// - Returns: Tuple of (inputs, targets) as MLMultiArrays
  /// - Throws: MLMultiArray conversion errors
  public func convertToMLMultiArrays(_ features: [FeatureVector]) throws -> ([MLMultiArray], [MLMultiArray]) {
    var inputs = [MLMultiArray]()
    var targets = [MLMultiArray]()

    for featureVector in features {
      let input = try featureVector.toMLMultiArray()
      let target = try featureVector.toTargetMLMultiArray()

      inputs.append(input)
      targets.append(target)
    }

    return (inputs, targets)
  }
}

// MARK: - Convenience Functions

public func generateFeatures(ticks: [ProbeTickRaw],
                             horizons: [Int] = defaultHorizons,
                             deterministicSeed: UInt64 = 42,
                             progressDelegate: FeatureEngineeringProgressDelegate? = nil) throws -> [[FeatureVector]]
{
  let config = FeatureEngineeringConfiguration(horizons: horizons,
                                               deterministicSeed: deterministicSeed)
  let service = FeatureEngineeringService(configuration: config, progressDelegate: progressDelegate)
  return try service.generateFeatures(from: ticks)
}

public func convertFeaturesToMLMultiArrays(_ features: [FeatureVector]) throws -> ([MLMultiArray], [MLMultiArray]) {
  let config = FeatureEngineeringConfiguration()
  let service = FeatureEngineeringService(configuration: config)
  return try service.convertToMLMultiArrays(features)
}
