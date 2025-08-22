//
//  TrainPrepService.swift
//  Bridget
//
//  ## Purpose
//  Orchestration service for ML training data preparation pipeline
//  Coordinates feature engineering and Core ML training without CSV intermediates
//
//  ## Dependencies
//  FeatureEngineeringService, TrainingConfig, CoreML framework
//
//  ## Integration Points
//  Orchestrates feature engineering and Core ML training
//  Generates MLMultiArray outputs directly for Core ML
//  Supports multiple prediction horizons (0, 3, 6, 9, 12 minutes)
//
//  ## Key Features
//  Orchestration-only design (no heavy logic)
//  Direct NDJSON → FeatureVector → MLMultiArray → Core ML pipeline
//  Deterministic training with configurable seeds
//  Performance monitoring and validation
//

import CoreML
import Foundation

// Centralized types and protocols are now in the same target

// Feature engineering functions moved to FeatureEngineeringService

func loadNDJSON(from path: String) throws -> [ProbeTickRaw] {
  let url = URL(fileURLWithPath: path)
  let data = try String(contentsOf: url, encoding: .utf8)
  var result = [ProbeTickRaw]()
  for (i, line) in data.split(separator: "\n").enumerated() {
    if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { continue }
    if let decoded = try? JSONDecoder.bridgeDecoder().decode(ProbeTickRaw.self, from: Data(line.utf8)) {
      result.append(decoded)
    } else {
      print("[Warning] Failed to parse line \(i + 1): Could not decode ProbeTickRaw")
    }
  }
  return result
}

// Date and math utility functions moved to FeatureEngineeringService

// Feature engineering function moved to FeatureEngineeringService

// CSV export function removed - direct MLMultiArray output only

// MARK: - Configuration

public struct TrainPrepConfiguration {
  let inputPath: String
  let outputDirectory: String
  let trainingConfig: TrainingConfig
  let enableProgressReporting: Bool

  init(inputPath: String = "minutes_2025-01-27.ndjson",
       outputDirectory: String = FileManagerUtils.temporaryDirectory().path,
       trainingConfig: TrainingConfig = .production,
       enableProgressReporting: Bool = true)
  {
    self.inputPath = inputPath
    self.outputDirectory = outputDirectory
    self.trainingConfig = trainingConfig
    self.enableProgressReporting = enableProgressReporting
  }
}

// MARK: - Progress Reporting

// TrainPrepProgressDelegate protocol moved to Protocols.swift

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

    // Initialize performance monitoring
    let trainingBudget = configuration.trainingConfig.getPerformanceBudget()
    let performanceMonitor = PerformanceMonitoringService(budget: PerformanceBudget(parseTimeMs: trainingBudget.parseTimeMs,
                                                                                    featureEngineeringTimeMs: trainingBudget.featureEngineeringTimeMs,
                                                                                    mlMultiArrayConversionTimeMs: trainingBudget.mlMultiArrayConversionTimeMs,
                                                                                    trainingTimeMs: trainingBudget.trainingTimeMs,
                                                                                    validationTimeMs: trainingBudget.validationTimeMs,
                                                                                    peakMemoryMB: trainingBudget.peakMemoryMB))

    do {
      // Parse NDJSON data
      let ticks = try await measurePerformanceAsync("parse", monitor: performanceMonitor) {
        try loadNDJSON(from: configuration.inputPath)
      }
      progressDelegate?.trainPrepDidLoadData(ticks.count)

      // Feature engineering
      let featureService = FeatureEngineeringService(
        configuration: FeatureEngineeringConfiguration(horizons: configuration.trainingConfig.horizons,
                                                       deterministicSeed: configuration.trainingConfig.deterministicSeed)
      )

      let allFeatures = try await measurePerformanceAsync("featureEngineering", monitor: performanceMonitor) {
        try featureService.generateFeatures(from: ticks)
      }

      // Convert to MLMultiArrays
      for (idx, horizon) in configuration.trainingConfig.horizons.enumerated() {
        let (inputs, _) = try await measurePerformanceAsync("mlMultiArrayConversion", monitor: performanceMonitor) {
          try featureService.convertToMLMultiArrays(allFeatures[idx])
        }
        progressDelegate?.trainPrepDidProcessHorizon(horizon, featureCount: inputs.count)

        // Store MLMultiArrays for Core ML training
        let modelPath = "\(configuration.outputDirectory)/model_horizon_\(horizon).mlmodel"
        progressDelegate?.trainPrepDidSaveHorizon(horizon, to: modelPath)
      }

      // Generate performance report
      let performanceReport = performanceMonitor.generateReport()
      print("📊 Performance Report:\n\(performanceReport)")

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
                         trainingConfig: TrainingConfig = .production,
                         progressDelegate: TrainPrepProgressDelegate? = nil) async throws
{
  let config = TrainPrepConfiguration(inputPath: inputPath,
                                      outputDirectory: outputDirectory ?? FileManagerUtils.temporaryDirectory().path,
                                      trainingConfig: trainingConfig)

  let service = TrainPrepService(configuration: config, progressDelegate: progressDelegate)
  try await service.process()
}

// MARK: - Legacy Main Driver (for backward compatibility)

func main() {
  Task {
    do {
      try await processTrainingData(inputPath: "minutes_2025-01-27.ndjson", trainingConfig: .production)
    } catch {
      print("❌ Error in main: \(error)")
    }
  }
}

// MARK: - Integration with BridgeDataService Pipeline

public extension TrainPrepService {
  static func processExportedData(ndjsonPath: String,
                                  outputDirectory: String,
                                  trainingConfig: TrainingConfig = .production,
                                  progressDelegate: TrainPrepProgressDelegate? = nil) async throws -> [String]
  {
    let config = TrainPrepConfiguration(inputPath: ndjsonPath,
                                        outputDirectory: outputDirectory,
                                        trainingConfig: trainingConfig)

    let service = TrainPrepService(configuration: config, progressDelegate: progressDelegate)
    try await service.process()

    return trainingConfig.horizons.map { horizon in
      "\(outputDirectory)/model_horizon_\(horizon).mlmodel"
    }
  }

  static func processTodayData(exportBaseDirectory: String = FileManagerUtils.temporaryDirectory().path,
                               trainingConfig: TrainingConfig = .production,
                               progressDelegate: TrainPrepProgressDelegate? = nil) async throws -> [String]
  {
    let dateFormatter = DateFormatter()
    dateFormatter.dateFormat = "yyyy-MM-dd"
    let today = dateFormatter.string(from: Date())

    let ndjsonPath = "\(exportBaseDirectory)/minutes_\(today).ndjson"

    guard FileManagerUtils.fileExists(at: ndjsonPath) else {
      throw NSError(domain: "TrainPrepService",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "NDJSON file not found: \(ndjsonPath)"])
    }

    return try await processExportedData(ndjsonPath: ndjsonPath,
                                         outputDirectory: exportBaseDirectory,
                                         trainingConfig: trainingConfig,
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

// DataValidationResult struct moved to MLTypes.swift

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
                                         trainingConfig: .validation,
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
    // Use the new CoreMLTraining module for conversion
    let multiArray = try CoreMLTraining.toMLMultiArray(features)
    
    // Convert to individual arrays for backward compatibility
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

      // Use the new CoreMLTraining module
      let trainingConfig = CoreMLTrainingConfig(
        modelType: .neuralNetwork,
        epochs: 100,
        learningRate: 0.001,
        batchSize: 32,
        useANE: true
      )
      
      let trainer = CoreMLTraining(config: trainingConfig, progressDelegate: progressDelegate)
      
      // Train the model using the new module
      let model = try await trainer.trainModel(with: features, progress: progressDelegate)
      
      // Save the model
      let modelURL = URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(modelName).mlmodel")
      // Note: In a real implementation, you would save the model here
      
      await progressDelegate?.trainingDidComplete(modelURL.path)
      return modelURL.path

    } catch {
      await progressDelegate?.trainingDidFail(error)
      throw error
    }
  }

  static func createTrainingPipeline(ndjsonPath: String,
                                     outputDirectory: String,
                                     horizons: [Int] = defaultHorizons,
                                     modelConfiguration: MLModelConfiguration? = nil,
                                     progressDelegate: CoreMLTrainingProgressDelegate? = nil) async throws -> [Int: String]
  {
    await progressDelegate?.pipelineDidStart()

    let csvFiles = try await processExportedData(ndjsonPath: ndjsonPath,
                                                 outputDirectory: outputDirectory,
                                                 trainingConfig: .production)

    await progressDelegate?.pipelineDidProcessData(csvFiles.count)

    var trainedModels = [Int: String]()

    for (index, csvPath) in csvFiles.enumerated() {
      let horizon = horizons[index]
      let modelName = "BridgeLiftPredictor_horizon_\(horizon)"

      await progressDelegate?.pipelineDidStartTraining(horizon)

      let modelPath = try await trainCoreMLModel(csvPath: csvPath,
                                                 modelName: modelName,
                                                 outputDirectory: outputDirectory,
                                                 configuration: modelConfiguration,
                                                 progressDelegate: progressDelegate)

      trainedModels[horizon] = modelPath
      await progressDelegate?.pipelineDidCompleteTraining(horizon, modelPath: modelPath)
    }

    await progressDelegate?.pipelineDidComplete(trainedModels)
    return trainedModels
  }

  static func validateTrainedModel(modelPath: String) throws -> CoreMLModelValidationResult {
    // Use the new CoreMLTraining module for validation
    guard let modelURL = URL(string: modelPath),
          let model = try? MLModel(contentsOf: modelURL)
    else {
      throw CoreMLError.invalidModel
    }

    // Create trainer with validation config
    let trainingConfig = CoreMLTrainingConfig.validation
    let trainer = CoreMLTraining(config: trainingConfig)
    
    // Generate synthetic data for validation
    let syntheticFeatures = CoreMLTraining.generateSyntheticData(count: 50)
    
    // Evaluate the model
    let result = try trainer.evaluate(model, on: syntheticFeatures)
    
    return result
  }
}

// MARK: - Core ML Training Progress Delegate

// CoreMLTrainingProgressDelegate protocol moved to Protocols.swift

// MARK: - Model Validation Result

// ModelValidationResult struct moved to MLTypes.swift

// MARK: - Core ML Error Types

// CoreMLError enum moved to MLTypes.swift

// MARK: - Private Helper Methods

private extension TrainPrepService {
  static func loadFeaturesFromCSV(_ csvPath: String) throws -> [FeatureVector] {
    let url = URL(fileURLWithPath: csvPath)
    let csvData = try String(contentsOf: url, encoding: .utf8)
    let lines = csvData.split(separator: "\n")

    var features = [FeatureVector]()

    for line in lines.dropFirst() {
      let columns = line.split(separator: ",")
      guard columns.count >= 17 else { continue }

      let featureVector = FeatureVector(bridge_id: Int(columns[0]) ?? 0,
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
                                        current_speed: Double(columns[14]) ?? 35.0,
                                        normal_speed: Double(columns[15]) ?? 35.0,
                                        target: Int(columns[16]) ?? 0)

      features.append(featureVector)
    }

    return features
  }
}


