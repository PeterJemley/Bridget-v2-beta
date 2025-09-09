// CoreMLFeatureConversion.swift
import CoreML
import Foundation

public protocol CoreMLFeatureConversionProtocol {
  func toMLMultiArray(_ features: [FeatureVector]) throws -> MLMultiArray
  func batchedArrays(from features: [FeatureVector], batchSize: Int) throws
    -> [(batchIndex: Int, array: MLMultiArray)]
}

public final class CoreMLFeatureConversion: CoreMLFeatureConversionProtocol {
  /// Converts arrays of FeatureVector into MLMultiArray for Core ML consumption
  /// - Parameter features: Array of feature vectors to convert
  /// - Returns: MLMultiArray with shape [batch_size, feature_count]
  /// - Throws: CoreMLTrainingError for shape mismatches and validation failures
  public func toMLMultiArray(_ features: [FeatureVector]) throws
    -> MLMultiArray
  {
    guard !features.isEmpty else {
      throw CoreMLTrainingError.insufficientData(required: 1,
                                                 available: 0)
    }

    // Validate all vectors have identical feature count
    let expectedFeatureCount = FeatureVector.featureCount
    for (index, feature) in features.enumerated() {
      let actualFeatures = [
        feature.min_sin, feature.min_cos, feature.dow_sin,
        feature.dow_cos,
        feature.open_5m, feature.open_30m, feature.detour_delta,
        feature.cross_rate,
        feature.via_routable, feature.via_penalty, feature.gate_anom,
        feature.detour_frac,
        feature.current_speed, feature.normal_speed,
      ]
      guard actualFeatures.count == expectedFeatureCount else {
        throw CoreMLTrainingError.shapeMismatch(expected: [expectedFeatureCount],
                                                found: [actualFeatures.count],
                                                context: "feature vector at index \(index)")
      }
    }

    // Create MLMultiArray with shape [batch_size, feature_count]
    let shape = [
      NSNumber(value: features.count),
      NSNumber(value: expectedFeatureCount),
    ]
    let array = try MLMultiArray(shape: shape, dataType: .double)

    // Populate data
    for (featureIndex, feature) in features.enumerated() {
      let values = [
        feature.min_sin, feature.min_cos, feature.dow_sin,
        feature.dow_cos,
        feature.open_5m, feature.open_30m, feature.detour_delta,
        feature.cross_rate,
        feature.via_routable, feature.via_penalty, feature.gate_anom,
        feature.detour_frac,
        feature.current_speed, feature.normal_speed,
      ]
      for (dimIndex, value) in values.enumerated() {
        array[[
          NSNumber(value: featureIndex), NSNumber(value: dimIndex),
        ]] = NSNumber(value: value)
      }
    }

    return array
  }

  /// Splits features into batches for memory efficiency and ANE/Metal acceleration
  /// - Parameters:
  ///   - features: Array of feature vectors to batch
  ///   - batchSize: Size of each batch
  /// - Returns: Array of MLMultiArray batches with batch indices for traceability
  public func batchedArrays(from features: [FeatureVector],
                            batchSize: Int) throws -> [(batchIndex: Int, array: MLMultiArray)]
  {
    guard batchSize > 0 else {
      throw CoreMLTrainingError.batchSizeTooLarge(batchSize: batchSize,
                                                  maxSize: 0)
    }
    guard batchSize <= features.count else {
      throw CoreMLTrainingError.batchSizeTooLarge(batchSize: batchSize,
                                                  maxSize: features.count)
    }

    var batches: [(batchIndex: Int, array: MLMultiArray)] = []
    let totalBatches = (features.count + batchSize - 1) / batchSize

    for batchIndex in 0 ..< totalBatches {
      let startIndex = batchIndex * batchSize
      let endIndex = min(startIndex + batchSize, features.count)
      let batchFeatures = Array(features[startIndex ..< endIndex])

      let batchArray = try toMLMultiArray(batchFeatures)
      batches.append((batchIndex: batchIndex, array: batchArray))
    }

    return batches
  }
}
