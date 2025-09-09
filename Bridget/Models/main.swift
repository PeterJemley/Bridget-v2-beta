// main.swift (MLHarness target)

import Foundation
import BridgetCore // or the framework module name if you chose a framework

@main
struct Harness {
  static func main() async {
    let env = ProcessInfo.processInfo.environment

    // Simple task selector
    let task = env["ML_TASK"] ?? "feature_engineering" // train | evaluate | feature_engineering
    let useSample = env["USE_SAMPLE_DATA"] == "1"
    let disableNetwork = env["DISABLE_NETWORK"] == "1"
    let disableCache = env["DISABLE_CACHE"] == "1"

    print("🔧 MLHarness starting. Task=\(task) sample=\(useSample) netOff=\(disableNetwork) cacheOff=\(disableCache)")

    do {
      switch task {
      case "feature_engineering":
        try await runFeatureEngineering(useSample: useSample,
                                       disableNetwork: disableNetwork,
                                       disableCache: disableCache)
      case "train":
        try await runTraining()
      case "evaluate":
        try await runEvaluation()
      default:
        print("❌ Unknown ML_TASK: \(task)")
        exit(2)
      }
      print("✅ Task completed.")
      exit(0)
    } catch {
      print("❌ Task failed: \(error)")
      exit(1)
    }
  }

  // MARK: - Tasks

  static func runFeatureEngineering(useSample: Bool,
                                    disableNetwork: Bool,
                                    disableCache: Bool) async throws {
    // You already have BridgeDataService. Reuse it here.
    // We’ll honor env vars by setting the same env in this process (BridgeDataService will read them).
    if useSample {
      let bridges = BridgeDataService.shared.loadSampleData()
      print("Loaded \(bridges.count) bridges from sample data.")
      // TODO: call your feature engineering service once implemented.
      return
    }

    // Optionally set env flags for BridgeDataService to see:
    setenv("DISABLE_NETWORK", disableNetwork ? "1" : "0", 1)
    setenv("DISABLE_CACHE", disableCache ? "1" : "0", 1)

    do {
      let (bridges, failures) = try await BridgeDataService.shared.loadHistoricalData()
      print("Loaded \(bridges.count) bridges. Validation failures: \(failures.count)")
      // TODO: call your feature engineering service once implemented.
    } catch {
      print("Network load failed: \(error)")
      throw error
    }
  }

  static func runTraining() async throws {
    // Placeholder: integrate your training service when ready
    // Read ML_COMPUTE_DEVICE, ML_DATA_DIR, ML_OUTPUT_DIR from env
    let env = ProcessInfo.processInfo.environment
    let device = env["ML_COMPUTE_DEVICE"] ?? "cpu"
    let dataDir = env["ML_DATA_DIR"] ?? "/tmp/features"
    let outDir = env["ML_OUTPUT_DIR"] ?? "/tmp/models"
    print("Training with device=\(device), dataDir=\(dataDir), outDir=\(outDir)")
    // TODO: implement training pipeline and progress delegates
  }

  static func runEvaluation() async throws {
    let env = ProcessInfo.processInfo.environment
    let modelsDir = env["ML_MODELS_DIR"] ?? "/tmp/models"
    let metricsOut = env["ML_METRICS_OUT"] ?? "/tmp/metrics.json"
    print("Evaluating models in \(modelsDir), writing metrics to \(metricsOut)")
    // TODO: implement evaluation and write metrics JSON
  }
}
