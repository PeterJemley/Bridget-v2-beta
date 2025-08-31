//
//  FeatureEngineeringService.swift
//  Bridget
//
//  ## Purpose
//  Feature engineering service for ML training data preparation
//  Extracted from TrainPrepService to maintain separation of concerns
//
//  ✅ STATUS: COMPLETE - All requirements implemented and tested
//  ✅ COMPLETION DATE: August 21, 2025
//  ✅ ENHANCED: Stateless validation, comprehensive testing, deterministic behavior
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
//  Pure, stateless, deterministic feature generation
//  Comprehensive validation with zero NaNs/Inf guarantee
//  Direct MLMultiArray output (no CSV intermediate)
//  Thread-safe and concurrent-ready
//  Extensive test coverage with large datasets and edge cases
//

import CoreML
import Foundation

// Centralized types and protocols are now in the same target

// MARK: - Error Types

/// Feature engineering specific errors
public enum FeatureEngineeringError: Error, LocalizedError {
  case invalidFeatureVector(bridgeId: Int,
                            timestamp: String,
                            horizon: Int,
                            description: String)
  case invalidInputData(description: String)
  case validationFailed(description: String)

  public var errorDescription: String? {
    switch self {
    case let .invalidFeatureVector(bridgeId, timestamp, horizon, description):
      return "Invalid feature vector for bridge \(bridgeId) at \(timestamp) horizon \(horizon): "
        + "\(description)"
    case let .invalidInputData(description):
      return "Invalid input data: \(description)"
    case let .validationFailed(description):
      return "Validation failed: \(description)"
    }
  }
}

// MARK: - Top-Level Helper Functions

/// Computes the cyclical encoding (sine and cosine) for a given value and period.
///
/// This function is used for encoding time-based features like minute of day and day of week
/// into cyclical representations that preserve the continuity of time.
///
/// - Parameters:
///   - x: The value to encode cyclically (e.g., minute of day 0-1439, day of week 1-7).
///   - period: The period of the cycle (e.g., 1440 for minutes, 7 for days).
/// - Returns: A tuple of (sine, cosine) values representing the cyclical encoding.
///
/// - Note: The encoding ensures that values at the boundary (e.g., 0 and 1440 minutes)
///         have similar representations, which is important for ML models.
///
/// - Example:
///   ```swift
///   let (sin, cos) = cyc(720, period: 1440) // Noon encoding
///   let (dowSin, dowCos) = cyc(1, period: 7) // Monday encoding
///   ```
public func cyc(_ x: Double, period: Double) -> (Double, Double) {
  let angle = 2 * Double.pi * x / period
  return (sin(angle), cos(angle))
}

/// Calculates rolling averages over a window for an array of optional Doubles.
///
/// This function computes rolling averages for time-series data, handling missing values
/// by excluding them from the calculation. Used for computing bridge opening patterns
/// over different time windows (5-minute and 30-minute averages).
///
/// - Parameters:
///   - input: The input array of optional Double values (e.g., bridge open/closed labels).
///   - window: The size of the rolling window (e.g., 5 for 5-minute average).
/// - Returns: An array of rolling average values, with zero used when no valid values exist.
///
/// - Note: The function handles missing values gracefully by excluding them from the average
///         calculation, ensuring robust feature generation even with incomplete data.
///
/// - Example:
///   ```swift
///   let labels = [1.0, nil, 0.0, 1.0, 1.0]
///   let avg5m = rollingAverage(labels, window: 3) // [1.0, 1.0, 0.5, 0.67, 0.67]
///   ```
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
///
/// Extracts the day of the week from a date using ISO8601 calendar, which is consistent
/// with the timezone policy defined in the contracts (America/Los_Angeles).
///
/// - Parameter date: The date to extract the weekday from.
/// - Returns: An integer representing the day of the week (Sunday=1, Monday=2, ..., Saturday=7).
///
/// - Note: Uses ISO8601 calendar for consistency with the project's timezone handling.
///         The returned value is used for cyclical encoding in feature generation.
///
/// - Example:
///   ```swift
///   let date = ISO8601DateFormatter().date(from: "2025-01-27T08:00:00Z")!
///   let dow = dayOfWeek(from: date) // Returns 2 for Monday
///   ```
public func dayOfWeek(from date: Date) -> Int {
  let calendar = Calendar(identifier: .iso8601)
  return calendar.component(.weekday, from: date)  // Sunday=1 ... Saturday=7
}

/// Returns the minute of the day (0-1439) for a given Date.
///
/// Extracts the minute of the day from a date, which is used for cyclical encoding
/// in feature generation. The result represents minutes since midnight.
///
/// - Parameter date: The date to extract the minute of the day from.
/// - Returns: An integer representing the minute of the day (0-1439).
///
/// - Note: The returned value is used for cyclical encoding with a period of 1440 minutes.
///         This ensures that 23:59 and 00:00 have similar representations.
///
/// - Example:
///   ```swift
///   let date = ISO8601DateFormatter().date(from: "2025-01-27T12:34:00Z")!
///   let minute = minuteOfDay(from: date) // Returns 754 (12*60 + 34)
///   ```
public func minuteOfDay(from date: Date) -> Int {
  let calendar = Calendar(identifier: .iso8601)
  let hour = calendar.component(.hour, from: date)
  let minute = calendar.component(.minute, from: date)
  return hour * 60 + minute
}

// MARK: - Validation Helpers

/// Validates that a value is not NaN or infinite
/// - Parameter value: The value to validate
/// - Returns: True if the value is valid (not NaN or infinite)
func isValidValue(_ value: Double) -> Bool {
  return !value.isNaN && !value.isInfinite
}

/// Validates all feature values in a FeatureVector
/// - Parameter featureVector: The feature vector to validate
/// - Returns: True if all features are valid
func validateFeatureVector(_ featureVector: FeatureVector) -> Bool {
  let features = [
    featureVector.min_sin,
    featureVector.min_cos,
    featureVector.dow_sin,
    featureVector.dow_cos,
    featureVector.open_5m,
    featureVector.open_30m,
    featureVector.detour_delta,
    featureVector.cross_rate,
    featureVector.via_routable,
    featureVector.via_penalty,
    featureVector.gate_anom,
    featureVector.detour_frac,
    featureVector.current_speed,
    featureVector.normal_speed,
  ]

  return features.allSatisfy { isValidValue($0) }
}

// MARK: - Pure Feature Generation Function

/// Pure, stateless feature generator function with comprehensive validation.
///
/// This function transforms raw probe tick data into feature vectors for ML training.
/// It implements the complete feature engineering pipeline as defined in the contracts:
/// - Cyclical encoding for time features (minute of day, day of week)
/// - Rolling averages for bridge opening patterns (5-minute and 30-minute)
/// - Normalization of penalty and anomaly values
/// - Cross-rate calculation with NaN handling
/// - Speed data integration
/// - Deterministic processing (no random number generation)
///
/// The function validates all outputs to ensure zero NaNs/Inf values as required
/// by Step 1 contracts, and produces deterministic results given the same input.
///
/// - Parameters:
///   - ticks: Raw probe tick data from NDJSON files
///   - horizons: List of prediction horizon offsets in minutes (e.g., [0, 3, 6, 9, 12])
///   - deterministicSeed: Seed parameter (kept for API compatibility, not used)
/// - Returns: Array of FeatureVector arrays, one per horizon
/// - Throws: FeatureEngineeringError if validation fails or invalid data detected
///
/// - Note: The function is truly stateless and deterministic. It groups data by bridge_id
///         and processes each bridge's time series independently. Each tick produces
///         feature vectors for all specified horizons.
///
/// - Example:
///   ```swift
///   let features = try makeFeatures(
///     from: probeTicks,
///     horizons: [0, 3, 6]
///   )
///   // Returns: [[FeatureVector]] where features[0] = horizon 0 features
///   //          features[1] = horizon 3 features,
///   //          features[2] = horizon 6 features
///   ```
public func makeFeatures(from ticks: [ProbeTickRaw],
                         horizons: [Int],
                         deterministicSeed _: UInt64 = 42) throws -> [[FeatureVector]]
{
  // Note: deterministicSeed parameter is kept for API compatibility
  // but no random number generation is used in this pure function

  let grouped = Dictionary(grouping: ticks) { $0.bridge_id }
  let isoFormatter = ISO8601DateFormatter()

  var allFeatures = Array(repeating: [FeatureVector](), count: horizons.count)

  for (_, bridgeTicks) in grouped {
    let sortedTicks = bridgeTicks.sorted {
      guard let d1 = isoFormatter.date(from: $0.ts_utc),
            let d2 = isoFormatter.date(from: $1.ts_utc)
      else {
        return false
      }
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

        let penaltyNorm =
          min(max(tick.via_penalty_sec ?? 0.0, 0.0),
              900.0) / 900.0

        let gateAnomNorm =
          min(max(tick.gate_anom ?? 1.0, 1.0),
              8.0) / 8.0

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

        // Validate feature vector (zero NaNs/Inf as per Step 1 contracts)
        guard validateFeatureVector(fv) else {
          throw FeatureEngineeringError.invalidFeatureVector(bridgeId: tick.bridge_id,
                                                             timestamp: tick.ts_utc,
                                                             horizon: horizon,
                                                             description: "Feature vector contains NaN or infinite values")
        }

        allFeatures[hIdx].append(fv)
      }
    }
  }

  return allFeatures
}

// MARK: - Main Service

/// Feature engineering service for ML training data preparation.
///
/// This service provides a high-level interface for feature engineering operations,
/// including progress reporting and configuration management. It wraps the pure
/// feature generation functions with additional functionality like progress tracking
/// and error handling.
///
/// The service is designed to be stateless and thread-safe, making it suitable
/// for use in concurrent processing pipelines.
public class FeatureEngineeringService {
  private let configuration: FeatureEngineeringConfiguration
  private weak var progressDelegate: FeatureEngineeringProgressDelegate?

  /// Initializes the feature engineering service with configuration and optional progress delegate.
  ///
  /// - Parameters:
  ///   - configuration: Feature engineering configuration including horizons and seed
  ///   - progressDelegate: Optional delegate for progress reporting during processing
  public init(configuration: FeatureEngineeringConfiguration,
              progressDelegate: FeatureEngineeringProgressDelegate? = nil)
  {
    self.configuration = configuration
    self.progressDelegate = progressDelegate
  }

  /// Generates feature vectors from probe tick data with deterministic processing.
  ///
  /// This method processes raw probe tick data through the complete feature engineering
  /// pipeline, including validation and progress reporting. It uses the service's
  /// configuration for horizons and deterministic seed.
  ///
  /// The method reports progress through the delegate and validates all outputs
  /// to ensure compliance with Step 1 contracts (zero NaNs/Inf values).
  ///
  /// - Parameter ticks: Raw probe tick data from NDJSON files
  /// - Returns: Array of feature vectors organized by horizon
  /// - Throws: FeatureEngineeringError if validation fails or processing errors occur
  ///
  /// - Note: Progress is reported through the delegate at start and completion.
  ///         The total feature count is reported upon completion.
  public func generateFeatures(from ticks: [ProbeTickRaw]) throws -> [[FeatureVector]] {
    progressDelegate?.featureEngineeringDidStart()

    let allFeatures = try makeFeatures(from: ticks,
                                       horizons: configuration.horizons,
                                       deterministicSeed: configuration.deterministicSeed)

    let totalFeatures = allFeatures.flatMap { $0 }.count
    progressDelegate?.featureEngineeringDidComplete(totalFeatures)

    return allFeatures
  }

  /// Converts feature vectors directly to MLMultiArray format for Core ML training.
  ///
  /// This method converts feature vectors into the MLMultiArray format required by
  /// Core ML for training and inference. It separates input features from target
  /// values and ensures proper shape formatting.
  ///
  /// The method uses the FeatureVector's built-in conversion methods to ensure
  /// consistency with the model's expected input/output shapes.
  ///
  /// - Parameter features: Array of feature vectors to convert
  /// - Returns: Tuple of (inputs, targets) as MLMultiArrays ready for Core ML
  /// - Throws: CoreMLError.dataConversionFailed if conversion fails
  ///
  /// - Note: The input MLMultiArrays have shape [featureCount, featureDimension]
  ///         and target MLMultiArrays have shape [featureCount, targetDimension].
  public func convertToMLMultiArrays(
    _ features: [FeatureVector]
  ) throws -> ([MLMultiArray], [MLMultiArray]) {
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

/// Convenience function for generating features with default configuration.
///
/// This function provides a simple interface for feature generation using default
/// parameters. It creates a temporary service instance and processes the data
/// with progress reporting if a delegate is provided.
///
/// - Parameters:
///   - ticks: Raw probe tick data from NDJSON files
///   - horizons: List of prediction horizon offsets (default: [0, 3, 6, 9, 12])
///   - deterministicSeed: Seed for reproducible processing (default: 42)
///   - progressDelegate: Optional delegate for progress reporting
/// - Returns: Array of feature vectors organized by horizon
/// - Throws: FeatureEngineeringError if validation fails or processing errors occur
///
/// - Note: This function is suitable for simple use cases where the full service
///         configuration is not needed. For complex pipelines, use the service class directly.
public func generateFeatures(ticks: [ProbeTickRaw],
                             horizons: [Int] = defaultHorizons,
                             deterministicSeed: UInt64 = 42,
                             progressDelegate: FeatureEngineeringProgressDelegate? = nil) throws -> [[FeatureVector]]
{
  let config = FeatureEngineeringConfiguration(horizons: horizons,
                                               deterministicSeed: deterministicSeed)
  let service = FeatureEngineeringService(configuration: config,
                                          progressDelegate: progressDelegate)
  return try service.generateFeatures(from: ticks)
}

/// Convenience function for converting feature vectors to MLMultiArrays.
///
/// This function provides a simple interface for converting feature vectors to
/// MLMultiArray format using default configuration.
///
/// - Parameter features: Array of feature vectors to convert
/// - Returns: Tuple of (inputs, targets) as MLMultiArrays ready for Core ML
/// - Throws: CoreMLError.dataConversionFailed if conversion fails
///
/// - Note: This function is suitable for simple conversion tasks. For complex
///         pipelines, use the service class directly.
public func convertFeaturesToMLMultiArrays(
  _ features: [FeatureVector]
) throws -> ([MLMultiArray], [MLMultiArray]) {
  let config = FeatureEngineeringConfiguration()
  let service = FeatureEngineeringService(configuration: config)
  return try service.convertToMLMultiArrays(features)
}
