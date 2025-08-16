//
//  TrainPrepService.swift
//  Bridget
//
//  ## Purpose
//  Swift implementation of ML training data preparation pipeline
//  Converts NDJSON probe data into ML-ready CSV training datasets
//
//  ## Dependencies
//  Foundation framework for I/O and JSON parsing
//
//  ## Integration Points
//  Processes exported probe data from BridgeDataExporter
//  Generates feature vectors for Core ML model training
//  Supports multiple prediction horizons (0, 3, 6, 9, 12 minutes)
//
//  ## Key Features
//  Feature engineering with cyclical encoding for time features
//  Rolling averages for recent bridge opening patterns
//  Multi-horizon target generation for time-series prediction
//  CSV export for ML training datasets
//

import CoreML
import Foundation

struct ProbeTickRaw: Codable {
  let v: Int?
  let ts_utc: String
  let bridge_id: Int
  let cross_k: Double?
  let cross_n: Double?
  let via_routable: Double?
  let via_penalty_sec: Double?
  let gate_anom: Double?
  let alternates_total: Double?
  let alternates_avoid: Double?
  let open_label: Int
  let detour_delta: Double?
  let detour_frac: Double?
}

public struct FeatureVector {
  let bridge_id: Int
  let horizon_min: Int
  let min_sin: Double
  let min_cos: Double
  let dow_sin: Double
  let dow_cos: Double
  let open_5m: Double
  let open_30m: Double
  let detour_delta: Double
  let cross_rate: Double
  let via_routable: Double
  let via_penalty: Double
  let gate_anom: Double
  let detour_frac: Double
  let target: Int

  /// Converts this feature vector to MLMultiArray format for Core ML training/inference.
  ///
  /// The shape is [1, featureCount] for single samples.
  ///
  /// - Returns: MLMultiArray containing the feature values
  /// - Throws: Error if MLMultiArray creation fails
  public func toMLMultiArray() throws -> MLMultiArray {
    let features = [
      min_sin, min_cos, dow_sin, dow_cos,
      open_5m, open_30m, detour_delta, cross_rate,
      via_routable, via_penalty, gate_anom, detour_frac
    ]

    let array = try MLMultiArray(shape: [1, NSNumber(value: features.count)], dataType: .double)

    for (i, value) in features.enumerated() {
      array[[0, i] as [NSNumber]] = NSNumber(value: value)
    }

    return array
  }

  /// Creates a target MLMultiArray for training.
  ///
  /// - Returns: MLMultiArray containing the target value
  /// - Throws: Error if MLMultiArray creation fails
  public func toTargetMLMultiArray() throws -> MLMultiArray {
    let array = try MLMultiArray(shape: [1, 1], dataType: .double)
    array[[0, 0] as [NSNumber]] = NSNumber(value: target)
    return array
  }

  static let featureCount = 12

  static let featureNames = [
    "min_sin", "min_cos", "dow_sin", "dow_cos",
    "open_5m", "open_30m", "detour_delta", "cross_rate",
    "via_routable", "via_penalty", "gate_anom", "detour_frac"
  ]
}

func cyc(_ x: Double, period: Double) -> (Double, Double) {
  let angle = 2 * Double.pi * x / period
  return (sin(angle), cos(angle))
}

func loadNDJSON(from path: String) throws -> [ProbeTickRaw] {
  let url = URL(fileURLWithPath: path)
  let data = try String(contentsOf: url, encoding: .utf8)
  var result = [ProbeTickRaw]()
  for (i, line) in data.split(separator: "\n").enumerated() {
    guard !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
    if let decoded = try? JSONDecoder().decode(ProbeTickRaw.self, from: Data(line.utf8)) {
      result.append(decoded)
    } else {
      print("[Warning] Failed to parse line \(i + 1): Could not decode ProbeTickRaw")
    }
  }
  return result
}

func rollingAverage(_ input: [Double?], window: Int) -> [Double] {
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

func dayOfWeek(from date: Date) -> Int {
  let calendar = Calendar(identifier: .iso8601)
  return calendar.component(.weekday, from: date) // Sunday=1 ... Saturday=7
}

func minuteOfDay(from date: Date) -> Int {
  let calendar = Calendar(identifier: .iso8601)
  let hour = calendar.component(.hour, from: date)
  let minute = calendar.component(.minute, from: date)
  return hour * 60 + minute
}

func featureEngineering(ticks: [ProbeTickRaw], horizons: [Int]) -> [[FeatureVector]] {
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

        let fv = FeatureVector(
          bridge_id: tick.bridge_id,
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
          target: target
        )
        allFeatures[hIdx].append(fv)
      }
    }
  }
  return allFeatures
}

func saveCSV(features: [FeatureVector], to path: String) {
  let header = "bridge_id,horizon_min,min_sin,min_cos,dow_sin,dow_cos,recent_open_5m,recent_open_30m,detour_delta,cross_rate_1m,via_routable,via_penalty,gate_anom,detour_frac,target"
  var lines = [header]
  for f in features {
    let line = "\(f.bridge_id),\(f.horizon_min),\(f.min_sin),\(f.min_cos),\(f.dow_sin),\(f.dow_cos),\(f.open_5m),\(f.open_30m),\(f.detour_delta),\(f.cross_rate),\(f.via_routable),\(f.via_penalty),\(f.gate_anom),\(f.detour_frac),\(f.target)"
    lines.append(line)
  }
  let csvData = lines.joined(separator: "\n")
  do {
    try csvData.write(toFile: path, atomically: true, encoding: .utf8)
    print("Saved CSV to \(path)")
  } catch {
    print("Failed to write CSV: \(error)")
  }
}

// MARK: - Configuration

public struct TrainPrepConfiguration {
  let inputPath: String
  let outputDirectory: String
  let outputBaseName: String
  let horizons: [Int]
  let enableProgressReporting: Bool

  init(inputPath: String = "minutes_2025-01-27.ndjson",
       outputDirectory: String = FileManager.default.currentDirectoryPath,
       outputBaseName: String = "training_data",
       horizons: [Int] = [0, 3, 6, 9, 12],
       enableProgressReporting: Bool = true)
  {
    self.inputPath = inputPath
    self.outputDirectory = outputDirectory
    self.outputBaseName = outputBaseName
    self.horizons = horizons
    self.enableProgressReporting = enableProgressReporting
  }
}

// MARK: - Progress Reporting

public protocol TrainPrepProgressDelegate: AnyObject {
  func trainPrepDidStart()
  func trainPrepDidLoadData(_ count: Int)
  func trainPrepDidProcessHorizon(_ horizon: Int, featureCount: Int)
  func trainPrepDidSaveHorizon(_ horizon: Int, to path: String)
  func trainPrepDidComplete()
  func trainPrepDidFail(_ error: Error)
}

// MARK: - Main Service

public class TrainPrepService {
  private let configuration: TrainPrepConfiguration
  private weak var progressDelegate: TrainPrepProgressDelegate?

  init(configuration: TrainPrepConfiguration, progressDelegate: TrainPrepProgressDelegate? = nil) {
    self.configuration = configuration
    self.progressDelegate = progressDelegate
  }

  func process() async throws {
    progressDelegate?.trainPrepDidStart()

    do {
      let ticks = try loadNDJSON(from: configuration.inputPath)
      progressDelegate?.trainPrepDidLoadData(ticks.count)

      let allFeatures = featureEngineering(ticks: ticks, horizons: configuration.horizons)

      for (idx, horizon) in configuration.horizons.enumerated() {
        let outputPath = "\(configuration.outputDirectory)/\(configuration.outputBaseName)_horizon_\(horizon).csv"
        saveCSV(features: allFeatures[idx], to: outputPath)
        progressDelegate?.trainPrepDidProcessHorizon(horizon, featureCount: allFeatures[idx].count)
        progressDelegate?.trainPrepDidSaveHorizon(horizon, to: outputPath)
      }

      progressDelegate?.trainPrepDidComplete()
      print("✅ Training data preparation complete!")

    } catch {
      progressDelegate?.trainPrepDidFail(error)
      print("❌ Error processing data: \(error)")
      throw error
    }
  }
}

// MARK: - Convenience Functions

func processTrainingData(inputPath: String,
                         outputDirectory: String? = nil,
                         outputBaseName: String = "training_data",
                         horizons: [Int] = [0, 3, 6, 9, 12],
                         progressDelegate: TrainPrepProgressDelegate? = nil) async throws
{
  let config = TrainPrepConfiguration(inputPath: inputPath,
                                      outputDirectory: outputDirectory ?? FileManager.default.currentDirectoryPath,
                                      outputBaseName: outputBaseName,
                                      horizons: horizons)

  let service = TrainPrepService(configuration: config, progressDelegate: progressDelegate)
  try await service.process()
}

// MARK: - Legacy Main Driver (for backward compatibility)

func main() {
  Task {
    do {
      try await processTrainingData(inputPath: "minutes_2025-01-27.ndjson")
    } catch {
      print("❌ Error in main: \(error)")
    }
  }
}

// MARK: - Integration with BridgeDataService Pipeline

public extension TrainPrepService {
  static func processExportedData(ndjsonPath: String,
                                  outputDirectory: String,
                                  horizons: [Int] = [0, 3, 6, 9, 12],
                                  progressDelegate: TrainPrepProgressDelegate? = nil) async throws -> [String]
  {
    let config = TrainPrepConfiguration(inputPath: ndjsonPath,
                                        outputDirectory: outputDirectory,
                                        outputBaseName: "training_data",
                                        horizons: horizons)

    let service = TrainPrepService(configuration: config, progressDelegate: progressDelegate)
    try await service.process()

    return horizons.map { horizon in
      "\(outputDirectory)/training_data_horizon_\(horizon).csv"
    }
  }

  static func processTodayData(exportBaseDirectory: String = FileManager.default.currentDirectoryPath,
                               horizons: [Int] = [0, 3, 6, 9, 12],
                               progressDelegate: TrainPrepProgressDelegate? = nil) async throws -> [String]
  {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let today = dateFormatter.string(from: Date())

    let ndjsonPath = "\(exportBaseDirectory)/minutes_\(today).ndjson"

    guard FileManager.default.fileExists(atPath: ndjsonPath) else {
      throw NSError(domain: "TrainPrepService",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "NDJSON file not found: \(ndjsonPath)"])
    }

    return try await processExportedData(ndjsonPath: ndjsonPath,
                                         outputDirectory: exportBaseDirectory,
                                         horizons: horizons,
                                         progressDelegate: progressDelegate)
  }

  static func validateExportedData(ndjsonPath: String) throws -> DataValidationResult {
    let ticks = try loadNDJSON(from: ndjsonPath)

    var result = DataValidationResult()
    result.totalRecords = ticks.count

    for tick in ticks {
      if tick.bridge_id < 0 || tick.bridge_id > 10 {
        result.invalidBridgeIds += 1
      }

      if tick.open_label != 0 && tick.open_label != 1 {
        result.invalidOpenLabels += 1
      }

      if let crossK = tick.cross_k, let crossN = tick.cross_n {
        if crossK > crossN {
          result.invalidCrossRatios += 1
        }
      }
    }

    let grouped = Dictionary(grouping: ticks) { $0.bridge_id }
    result.bridgeCount = grouped.count

    for (bridgeId, bridgeTicks) in grouped {
      result.recordsPerBridge[bridgeId] = bridgeTicks.count
    }

    result.isValid = result.invalidBridgeIds == 0 &&
      result.invalidOpenLabels == 0 &&
      result.invalidCrossRatios == 0

    return result
  }
}

// MARK: - Data Validation Result

public struct DataValidationResult {
  var totalRecords = 0
  var bridgeCount = 0
  var invalidBridgeIds = 0
  var invalidOpenLabels = 0
  var invalidCrossRatios = 0
  var recordsPerBridge: [Int: Int] = [:]
  var isValid = false

  var summary: String {
    """
    Data Validation Summary:
    - Total Records: \(totalRecords)
    - Bridges: \(bridgeCount)
    - Invalid Bridge IDs: \(invalidBridgeIds)
    - Invalid Open Labels: \(invalidOpenLabels)
    - Invalid Cross Ratios: \(invalidCrossRatios)
    - Valid: \(isValid ? "Yes" : "No")
    """
  }
}

// MARK: - Integration Test Methods

public extension TrainPrepService {
  static func runIntegrationTest(outputDirectory: String) async throws -> [String] {
    let testData = """
    {"v":1,"ts_utc":"2025-01-27T08:00:00Z","bridge_id":1,"cross_k":5,"cross_n":10,"via_routable":1,"via_penalty_sec":120,"gate_anom":2.5,"alternates_total":3,"alternates_avoid":1,"open_label":0,"detour_delta":30,"detour_frac":0.1}
    {"v":1,"ts_utc":"2025-01-27T08:01:00Z","bridge_id":1,"cross_k":6,"cross_n":10,"via_routable":1,"via_penalty_sec":150,"gate_anom":2.8,"alternates_total":3,"alternates_avoid":1,"open_label":1,"detour_delta":45,"detour_frac":0.15}
    {"v":1,"ts_utc":"2025-01-27T08:02:00Z","bridge_id":2,"cross_k":3,"cross_n":8,"via_routable":0,"via_penalty_sec":300,"gate_anom":1.5,"alternates_total":2,"alternates_avoid":0,"open_label":0,"detour_delta":-10,"detour_frac":0.05}
    """

    let testFilePath = "\(outputDirectory)/test_integration.ndjson"
    try testData.write(toFile: testFilePath, atomically: true, encoding: .utf8)

    let testDelegate = TestProgressDelegate()
    return try await processExportedData(ndjsonPath: testFilePath,
                                         outputDirectory: outputDirectory,
                                         horizons: [0, 3],
                                         progressDelegate: testDelegate)
  }
}

// MARK: - Test Progress Delegate

class TestProgressDelegate: TrainPrepProgressDelegate {
  func trainPrepDidStart() {
    print("🧪 Integration test started")
  }

  func trainPrepDidLoadData(_ count: Int) {
    print("🧪 Loaded \(count) test records")
  }

  func trainPrepDidProcessHorizon(_ horizon: Int, featureCount: Int) {
    print("🧪 Processed horizon \(horizon) with \(featureCount) features")
  }

  func trainPrepDidSaveHorizon(_ horizon: Int, to path: String) {
    print("🧪 Saved horizon \(horizon) to \(path)")
  }

  func trainPrepDidComplete() {
    print("🧪 Integration test completed successfully")
  }

  func trainPrepDidFail(_ error: Error) {
    print("🧪 Integration test failed: \(error)")
  }
}

// MARK: - Core ML Training Integration

public extension TrainPrepService {
  static func convertFeaturesToMLMultiArray(_ features: [FeatureVector]) throws -> ([MLMultiArray], [MLMultiArray]) {
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

  static func trainCoreMLModel(csvPath: String,
                               modelName: String,
                               outputDirectory: String,
                               configuration: MLModelConfiguration? = nil,
                               progressDelegate: CoreMLTrainingProgressDelegate? = nil) async throws -> String
  {
    await progressDelegate?.trainingDidStart()

    do {
      let features = try loadFeaturesFromCSV(csvPath)
      await progressDelegate?.trainingDidLoadData(features.count)

      let modelConfig = configuration ?? MLModelConfiguration().apply {
        $0.computeUnits = .all
        $0.allowLowPrecisionAccumulationOnGPU = true
      }

      let (inputs, targets) = try convertFeaturesToMLMultiArray(features)
      await progressDelegate?.trainingDidPrepareData(inputs.count)

      let modelURL = try await createAndTrainModel(
        inputs: inputs,
        targets: targets,
        modelName: modelName,
        outputDirectory: outputDirectory,
        configuration: modelConfig,
        progressDelegate: progressDelegate
      )

      await progressDelegate?.trainingDidComplete(modelURL.path)
      return modelURL.path

    } catch {
      await progressDelegate?.trainingDidFail(error)
      throw error
    }
  }

  static func createTrainingPipeline(ndjsonPath: String,
                                     outputDirectory: String,
                                     horizons: [Int] = [0, 3, 6, 9, 12],
                                     modelConfiguration: MLModelConfiguration? = nil,
                                     progressDelegate: CoreMLTrainingProgressDelegate? = nil) async throws -> [Int: String]
  {
    await progressDelegate?.pipelineDidStart()

    let csvFiles = try await processExportedData(ndjsonPath: ndjsonPath,
                                                 outputDirectory: outputDirectory,
                                                 horizons: horizons)

    await progressDelegate?.pipelineDidProcessData(csvFiles.count)

    var trainedModels = [Int: String]()

    for (index, csvPath) in csvFiles.enumerated() {
      let horizon = horizons[index]
      let modelName = "BridgeLiftPredictor_horizon_\(horizon)"

      await progressDelegate?.pipelineDidStartTraining(horizon)

      let modelPath = try await trainCoreMLModel(
        csvPath: csvPath,
        modelName: modelName,
        outputDirectory: outputDirectory,
        configuration: modelConfiguration,
        progressDelegate: progressDelegate
      )

      trainedModels[horizon] = modelPath
      await progressDelegate?.pipelineDidCompleteTraining(horizon, modelPath: modelPath)
    }

    await progressDelegate?.pipelineDidComplete(trainedModels)
    return trainedModels
  }

  static func validateTrainedModel(modelPath: String) throws -> ModelValidationResult {
    guard let modelURL = URL(string: modelPath),
          let model = try? MLModel(contentsOf: modelURL)
    else {
      throw CoreMLError.invalidModel
    }

    var result = ModelValidationResult()
    result.modelPath = modelPath
    result.modelDescription = model.modelDescription

    let sampleInput = try createSampleInput()
    let prediction = try model.prediction(from: sampleInput)

    result.samplePrediction = prediction
    result.isValid = true

    return result
  }
}

// MARK: - Core ML Training Progress Delegate

@MainActor
public protocol CoreMLTrainingProgressDelegate: AnyObject, Sendable {
  func trainingDidStart()
  func trainingDidLoadData(_ count: Int)
  func trainingDidPrepareData(_ count: Int)
  func trainingDidUpdateProgress(_ progress: Double)
  func trainingDidComplete(_ modelPath: String)
  func trainingDidFail(_ error: Error)

  func pipelineDidStart()
  func pipelineDidProcessData(_ fileCount: Int)
  func pipelineDidStartTraining(_ horizon: Int)
  func pipelineDidCompleteTraining(_ horizon: Int, modelPath: String)
  func pipelineDidComplete(_ models: [Int: String])
}

// MARK: - Model Validation Result

public struct ModelValidationResult {
  var modelPath = ""
  var modelDescription: MLModelDescription?
  var samplePrediction: MLFeatureProvider?
  var isValid = false

  var summary: String {
    """
    Model Validation Summary:
    - Model Path: \(modelPath)
    - Valid: \(isValid ? "Yes" : "No")
    - Description: \(modelDescription?.inputDescriptionsByName.keys.joined(separator: ", ") ?? "Unknown")
    """
  }
}

// MARK: - Core ML Error Types

enum CoreMLError: Error, LocalizedError {
  case invalidModel
  case trainingFailed(String)
  case dataConversionFailed
  case modelCreationFailed

  var errorDescription: String? {
    switch self {
    case .invalidModel:
      return "Invalid Core ML model"
    case let .trainingFailed(reason):
      return "Training failed: \(reason)"
    case .dataConversionFailed:
      return "Failed to convert data to MLMultiArray format"
    case .modelCreationFailed:
      return "Failed to create Core ML model"
    }
  }
}

// MARK: - Private Helper Methods

private extension TrainPrepService {
  static func loadFeaturesFromCSV(_ csvPath: String) throws -> [FeatureVector] {
    let url = URL(fileURLWithPath: csvPath)
    let csvData = try String(contentsOf: url, encoding: .utf8)
    let lines = csvData.split(separator: "\n")

    var features = [FeatureVector]()

    for line in lines.dropFirst() {
      let columns = line.split(separator: ",")
      guard columns.count >= 15 else { continue }

      let featureVector = FeatureVector(
        bridge_id: Int(columns[0]) ?? 0,
        horizon_min: Int(columns[1]) ?? 0,
        min_sin: Double(columns[2]) ?? 0.0,
        min_cos: Double(columns[3]) ?? 0.0,
        dow_sin: Double(columns[4]) ?? 0.0,
        dow_cos: Double(columns[5]) ?? 0.0,
        open_5m: Double(columns[6]) ?? 0.0,
        open_30m: Double(columns[7]) ?? 0.0,
        detour_delta: Double(columns[8]) ?? 0.0,
        cross_rate: Double(columns[9]) ?? 0.0,
        via_routable: Double(columns[10]) ?? 0.0,
        via_penalty: Double(columns[11]) ?? 0.0,
        gate_anom: Double(columns[12]) ?? 0.0,
        detour_frac: Double(columns[13]) ?? 0.0,
        target: Int(columns[14]) ?? 0
      )

      features.append(featureVector)
    }

    return features
  }

  static func createAndTrainModel(inputs: [MLMultiArray],
                                  targets: [MLMultiArray],
                                  modelName: String,
                                  outputDirectory: String,
                                  configuration: MLModelConfiguration,
                                  progressDelegate: CoreMLTrainingProgressDelegate?) async throws -> URL
  {
    let baseModelURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent("base_model.mlmodel")

    var featureProviders = [MLFeatureProvider]()

    for (input, target) in zip(inputs, targets) {
      let dict: [String: MLFeatureValue] = [
        "input": MLFeatureValue(multiArray: input),
        "target": MLFeatureValue(multiArray: target)
      ]
      try featureProviders.append(MLDictionaryFeatureProvider(dictionary: dict))
    }

    let batch = MLArrayBatchProvider(array: featureProviders)

    let progressHandlers = MLUpdateProgressHandlers(
      forEvents: [.trainingBegin, .miniBatchEnd, .epochEnd],
      progressHandler: { [weak progressDelegate] _ in
        let progress = 0.5
        Task { @MainActor in
          progressDelegate?.trainingDidUpdateProgress(progress)
        }
      },
      completionHandler: { [weak progressDelegate] context in
        if let error = context.task.error {
          Task { @MainActor in
            progressDelegate?.trainingDidFail(error)
          }
        }
      }
    )

    return try await withCheckedThrowingContinuation { continuation in
      do {
        let task = try MLUpdateTask(
          forModelAt: baseModelURL,
          trainingData: batch,
          configuration: configuration,
          progressHandlers: progressHandlers
        )

        task.resume()

        let modelURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(modelName).mlmodel")

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak progressDelegate] in
          Task { @MainActor in
            progressDelegate?.trainingDidComplete(modelURL.path)
          }
          continuation.resume(returning: modelURL)
        }

      } catch {
        continuation.resume(throwing: error)
      }
    }
  }

  static func createSampleInput() throws -> MLFeatureProvider {
    let sampleFeature = FeatureVector(
      bridge_id: 1,
      horizon_min: 0,
      min_sin: 0.5,
      min_cos: 0.866,
      dow_sin: 0.0,
      dow_cos: 1.0,
      open_5m: 0.2,
      open_30m: 0.1,
      detour_delta: 30.0,
      cross_rate: 0.8,
      via_routable: 1.0,
      via_penalty: 0.3,
      gate_anom: 0.5,
      detour_frac: 0.1,
      target: 0
    )

    let inputArray = try sampleFeature.toMLMultiArray()

    let dict: [String: MLFeatureValue] = [
      "input": MLFeatureValue(multiArray: inputArray)
    ]

    return try MLDictionaryFeatureProvider(dictionary: dict)
  }
}

// MARK: - MLModelConfiguration Extension

extension MLModelConfiguration {
  func apply(_ block: (MLModelConfiguration) -> Void) -> MLModelConfiguration {
    block(self)
    return self
  }
}

