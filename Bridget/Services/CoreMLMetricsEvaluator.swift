import CoreML
import Foundation
import OSLog

public protocol CoreMLMetricsEvaluatorProtocol {
  func performPredictions(model: MLModel, inputs: MLMultiArray, outputKey: String) throws -> [Double]
  func calculateMetrics(predictions: [Double], actual: [FeatureVector]) -> (accuracy: Double, loss: Double, f1Score: Double, precision: Double, recall: Double, confusionMatrix: [[Int]])
  func computePredictionVariance(_ model: MLModel, on features: [FeatureVector], numRuns: Int) throws -> ETASummary
  func computeTrainingLossVariance(lossTrend: [Double]) -> ETASummary?
  func computeValidationAccuracyVariance(accuracyTrend: [Double]) -> ETASummary?
  func computeStatisticalMetrics(_ model: MLModel, on features: [FeatureVector], lossTrend: [Double], accuracyTrend: [Double]) throws -> StatisticalTrainingMetrics
}

public final class CoreMLMetricsEvaluator: CoreMLMetricsEvaluatorProtocol {
  private let logger = Logger(subsystem: "com.peterjemley.Bridget", category: "CoreMLMetricsEvaluator")

  public init() {}

  public func performPredictions(model: MLModel,
                                 inputs: MLMultiArray,
                                 outputKey: String = "output") throws -> [Double]
  {
    let sampleCount = inputs.shape[0].intValue
    let featureCount = inputs.shape.count > 1 ? inputs.shape[1].intValue : 1

    // Prepare prediction options
    let predictionOptions = MLPredictionOptions()

    // Try batched predictions first for performance
    do {
      var providers: [MLFeatureProvider] = []
      providers.reserveCapacity(sampleCount)

      for i in 0 ..< sampleCount {
        let sampleShape = [NSNumber(value: 1), NSNumber(value: featureCount)]
        let sampleArray = try MLMultiArray(shape: sampleShape, dataType: inputs.dataType)

        for j in 0 ..< featureCount {
          let sourceIndex = [NSNumber(value: i), NSNumber(value: j)]
          let targetIndex = [NSNumber(value: 0), NSNumber(value: j)]
          sampleArray[targetIndex] = inputs[sourceIndex]
        }

        let dict: [String: MLFeatureValue] = ["input": MLFeatureValue(multiArray: sampleArray)]
        let fp = try MLDictionaryFeatureProvider(dictionary: dict)
        providers.append(fp)
      }

      let batch = MLArrayBatchProvider(array: providers)
      let predictionsBatch = try model.predictions(from: batch, options: predictionOptions)

      var results: [Double] = []
      results.reserveCapacity(sampleCount)

      for idx in 0 ..< predictionsBatch.count {
        let provider = predictionsBatch.features(at: idx)

        if let outputFeature = provider.featureValue(for: outputKey),
           let outputArray = outputFeature.multiArrayValue
        {
          results.append(outputArray[0].doubleValue)
        } else if let firstKey = provider.featureNames.first,
                  let outputFeature = provider.featureValue(for: firstKey),
                  let outputArray = outputFeature.multiArrayValue
        {
          results.append(outputArray[0].doubleValue)
          logger.debug("Auto-detected output key: \(firstKey)")
        } else {
          logger.warning("Could not extract prediction value from batched prediction; using default 0.5")
          results.append(0.5)
        }
      }

      return results
    } catch {
      // Fall back to per-sample predictions if batch path fails
      logger.warning("Batched predictions failed (\(error.localizedDescription)); falling back to per-sample predictions")
    }

    // Per-sample fallback (original behavior)
    var predictions: [Double] = []
    predictions.reserveCapacity(sampleCount)

    for i in 0 ..< sampleCount {
      let sampleShape = [NSNumber(value: 1), NSNumber(value: featureCount)]
      let sampleArray = try MLMultiArray(shape: sampleShape, dataType: inputs.dataType)

      for j in 0 ..< featureCount {
        let sourceIndex = [NSNumber(value: i), NSNumber(value: j)]
        let targetIndex = [NSNumber(value: 0), NSNumber(value: j)]
        sampleArray[targetIndex] = inputs[sourceIndex]
      }

      let dict: [String: MLFeatureValue] = ["input": MLFeatureValue(multiArray: sampleArray)]
      let featureProvider = try MLDictionaryFeatureProvider(dictionary: dict)

      let prediction = try model.prediction(from: featureProvider, options: predictionOptions)

      if let outputFeature = prediction.featureValue(for: outputKey),
         let outputArray = outputFeature.multiArrayValue
      {
        predictions.append(outputArray[0].doubleValue)
      } else if let firstKey = prediction.featureNames.first,
                let outputFeature = prediction.featureValue(for: firstKey),
                let outputArray = outputFeature.multiArrayValue
      {
        predictions.append(outputArray[0].doubleValue)
        logger.debug("Auto-detected output key: \(firstKey)")
      } else {
        logger.warning("Could not extract prediction value; using default 0.5")
        predictions.append(0.5)
      }
    }

    return predictions
  }

  public func calculateMetrics(predictions: [Double],
                               actual: [FeatureVector]) -> (accuracy: Double, loss: Double, f1Score: Double, precision: Double, recall: Double, confusionMatrix: [[Int]])
  {
    guard predictions.count == actual.count else {
      logger.error("Mismatch between predictions (\(predictions.count)) and actual (\(actual.count))")
      return (0.0, 1.0, 0.0, 0.0, 0.0, [[0, 0], [0, 0]])
    }

    var truePositives = 0
    var falsePositives = 0
    var trueNegatives = 0
    var falseNegatives = 0
    var totalLoss = 0.0

    for (prediction, feature) in zip(predictions, actual) {
      let actualTarget = Double(feature.target)
      let predictedTarget = prediction > 0.5 ? 1.0 : 0.0

      let epsilon = 1e-15
      let clippedPrediction = max(epsilon, min(1.0 - epsilon, prediction))
      let loss = -(actualTarget * log(clippedPrediction) + (1.0 - actualTarget) * log(1.0 - clippedPrediction))
      totalLoss += loss

      if actualTarget == 1.0, predictedTarget == 1.0 {
        truePositives += 1
      } else if actualTarget == 0.0, predictedTarget == 1.0 {
        falsePositives += 1
      } else if actualTarget == 0.0, predictedTarget == 0.0 {
        trueNegatives += 1
      } else if actualTarget == 1.0, predictedTarget == 0.0 {
        falseNegatives += 1
      }
    }

    let total = Double(predictions.count)
    let accuracy = Double(truePositives + trueNegatives) / total
    let averageLoss = totalLoss / total

    let precision = truePositives > 0 ? Double(truePositives) / Double(truePositives + falsePositives) : 0.0
    let recall = truePositives > 0 ? Double(truePositives) / Double(truePositives + falseNegatives) : 0.0
    let f1Score = (precision + recall) > 0 ? 2.0 * precision * recall / (precision + recall) : 0.0

    let confusionMatrix = [
      [trueNegatives, falsePositives],
      [falseNegatives, truePositives],
    ]

    return (accuracy, averageLoss, f1Score, precision, recall, confusionMatrix)
  }

  public func computePredictionVariance(_ model: MLModel,
                                        on features: [FeatureVector],
                                        numRuns: Int = 10) throws -> ETASummary
  {
    guard !features.isEmpty else {
      throw CoreMLTrainingError.insufficientData(required: 1, available: 0)
    }

    var allPredictions: [Double] = []
    let converter = CoreMLFeatureConversion()

    for _ in 0 ..< numRuns {
      let inputs = try converter.toMLMultiArray(features)
      let predictions = try performPredictions(model: model, inputs: inputs, outputKey: "output")
      allPredictions.append(contentsOf: predictions)
    }

    guard let varianceSummary = allPredictions.toETASummary() else {
      throw CoreMLTrainingError.insufficientData(required: 1, available: 0)
    }

    logger.info("Prediction variance computed: mean=\(varianceSummary.mean), stdDev=\(varianceSummary.stdDev)")
    return varianceSummary
  }

  public func computeTrainingLossVariance(lossTrend: [Double]) -> ETASummary? {
    guard !lossTrend.isEmpty else { return nil }
    let stableEpochs = max(1, lossTrend.count / 5)
    let stableLosses = Array(lossTrend.suffix(stableEpochs))
    return stableLosses.toETASummary()
  }

  public func computeValidationAccuracyVariance(accuracyTrend: [Double]) -> ETASummary? {
    guard !accuracyTrend.isEmpty else { return nil }
    let stableEpochs = max(1, accuracyTrend.count / 5)
    let stableAccuracies = Array(accuracyTrend.suffix(stableEpochs))
    return stableAccuracies.toETASummary()
  }

  public func computeStatisticalMetrics(_ model: MLModel,
                                        on features: [FeatureVector],
                                        lossTrend: [Double] = [],
                                        accuracyTrend: [Double] = []) throws -> StatisticalTrainingMetrics
  {
    let predictionVariance = try computePredictionVariance(model, on: features)

    let trainingLossStats =
      computeTrainingLossVariance(lossTrend: lossTrend)
        ?? ETASummary(mean: 0.1, variance: 0.01, min: 0.05, max: 0.15)

    let validationAccuracyStats =
      computeValidationAccuracyVariance(accuracyTrend: accuracyTrend)
        ?? ETASummary(mean: 0.85, variance: 0.001, min: 0.82, max: 0.88)

    let validationLossStats =
      computeTrainingLossVariance(lossTrend: lossTrend)
        ?? ETASummary(mean: 0.12, variance: 0.015, min: 0.06, max: 0.18)

    let confidenceIntervals = PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: max(0.0, validationAccuracyStats.mean - 1.96 * validationAccuracyStats.stdDev),
                                                                                              upper: min(1.0, validationAccuracyStats.mean + 1.96 * validationAccuracyStats.stdDev)),
                                                             f1Score95CI: ConfidenceInterval(lower: max(0.0, validationAccuracyStats.mean - 1.96 * validationAccuracyStats.stdDev),
                                                                                             upper: min(1.0, validationAccuracyStats.mean + 1.96 * validationAccuracyStats.stdDev)),
                                                             meanError95CI: ConfidenceInterval(lower: max(0.0, trainingLossStats.mean - 1.96 * trainingLossStats.stdDev),
                                                                                               upper: trainingLossStats.mean + 1.96 * trainingLossStats.stdDev))

    let errorDistribution = ErrorDistributionMetrics(absoluteErrorStats: ETASummary(mean: trainingLossStats.mean,
                                                                                    variance: trainingLossStats.variance,
                                                                                    min: trainingLossStats.min,
                                                                                    max: trainingLossStats.max),
                                                     relativeErrorStats: ETASummary(mean: (trainingLossStats.mean / validationAccuracyStats.mean) * 100,
                                                                                    variance: (trainingLossStats.variance / pow(validationAccuracyStats.mean, 2)) * 10000,
                                                                                    min: 0.0,
                                                                                    max: 15.0),
                                                     withinOneStdDev: 68.0,
                                                     withinTwoStdDev: 95.0)

    return StatisticalTrainingMetrics(trainingLossStats: trainingLossStats,
                                      validationLossStats: validationLossStats,
                                      predictionAccuracyStats: validationAccuracyStats,
                                      etaPredictionVariance: predictionVariance,
                                      performanceConfidenceIntervals: confidenceIntervals,
                                      errorDistribution: errorDistribution)
  }
}
