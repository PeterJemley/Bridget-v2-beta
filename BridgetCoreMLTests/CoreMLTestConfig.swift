// CoreMLTestConfig.swift
// Add this file to your test target.

import CoreML
import Foundation

public struct CoreMLTestConfig: CustomStringConvertible {
    public enum ComputeUnits: String {
        case cpu_only = "CPU_ONLY"
        case cpu_and_gpu = "CPU_AND_GPU"
        case all = "ALL"
    }

    // Environment variable keys
    static let envComputeUnits = "ML_COMPUTE_UNITS"  // CPU_ONLY | CPU_AND_GPU | ALL
    static let envPreferANE = "ML_PREFER_ANE"        // true | false (hint; effective only when available)
    static let envBatchSize = "ML_BATCH_SIZE"        // Int (your test logic can use this)
    static let envTimeoutSec = "ML_PREDICTION_TIMEOUT" // Double seconds (your test logic can use this)
    static let envLowPrecision = "ML_ALLOW_LOW_PRECISION" // true | false (if you choose to gate low-precision paths in your code)

    // Parsed values
    public let computeUnits: ComputeUnits
    public let preferANE: Bool
    public let batchSize: Int
    public let predictionTimeout: TimeInterval
    public let allowLowPrecision: Bool

    // Optional model-specific defaults you can tailor to your models.
    // Environment variables take precedence over these defaults.
    public struct ModelProfile {
        public let computeUnits: ComputeUnits
        public let batchSize: Int
        public let predictionTimeout: TimeInterval

        public init(computeUnits: ComputeUnits,
                    batchSize: Int,
                    predictionTimeout: TimeInterval) {
            self.computeUnits = computeUnits
            self.batchSize = batchSize
            self.predictionTimeout = predictionTimeout
        }
    }

    // Edit/extend this map with your actual model names (or file basenames without extension).
    // These are sensible starting points; adjust as needed.
    public static var modelProfiles: [String: ModelProfile] = [:]
    // Examples:
    // "SentimentClassifier": .init(computeUnits: .cpu_only, batchSize: 64, predictionTimeout: 30),
    // "ImageClassifier":    .init(computeUnits: .all,      batchSize: 16, predictionTimeout: 180),
    // "ObjectDetector":     .init(computeUnits: .all,      batchSize: 8,  predictionTimeout: 240),
    // "TabularRegressor":   .init(computeUnits: .cpu_and_gpu, batchSize: 128, predictionTimeout: 45),

    // Base config sourced from environment (or hard defaults).
    public static var current: CoreMLTestConfig {
        let env = ProcessInfo.processInfo.environment

        let computeUnits =
            ComputeUnits(rawValue: env[envComputeUnits]?.uppercased() ?? "")
            ?? .all
        let preferANE = Self.bool(from: env[envPreferANE], default: true)
        let batchSize = Self.int(from: env[envBatchSize], default: 32)
        let timeout = Self.double(from: env[envTimeoutSec], default: 60.0)
        let allowLowPrecision = Self.bool(
            from: env[envLowPrecision],
            default: false
        )

        return CoreMLTestConfig(
            computeUnits: computeUnits,
            preferANE: preferANE,
            batchSize: batchSize,
            predictionTimeout: timeout,
            allowLowPrecision: allowLowPrecision
        )
    }

    // Returns a config that applies a model-specific profile where environment variables are not set.
    // Precedence: explicit overrides in env > model profile > hard defaults.
    public static func current(applyingModelName modelName: String?)
        -> CoreMLTestConfig
    {
        guard let modelName, let profile = modelProfiles[modelName] else {
            return current
        }

        let env = ProcessInfo.processInfo.environment
        let envHasCompute = env[envComputeUnits] != nil
        let envHasBatch = env[envBatchSize] != nil
        let envHasTimeout = env[envTimeoutSec] != nil

        let base = current

        let resolvedCompute =
            envHasCompute ? base.computeUnits : profile.computeUnits
        let resolvedBatch = envHasBatch ? base.batchSize : profile.batchSize
        let resolvedTimeout =
            envHasTimeout ? base.predictionTimeout : profile.predictionTimeout

        return CoreMLTestConfig(
            computeUnits: resolvedCompute,
            preferANE: base.preferANE,
            batchSize: resolvedBatch,
            predictionTimeout: resolvedTimeout,
            allowLowPrecision: base.allowLowPrecision
        )
    }

    public func modelConfiguration() -> MLModelConfiguration {
        let cfg = MLModelConfiguration()

        switch computeUnits {
        case .cpu_only:
            cfg.computeUnits = .cpuOnly
        case .cpu_and_gpu:
            cfg.computeUnits = .cpuAndGPU
        case .all:
            cfg.computeUnits = .all
        }

        // There is no direct "prefer ANE" flag in MLModelConfiguration.
        _ = preferANE
        _ = allowLowPrecision

        return cfg
    }

    // Helpers
    private static func bool(from value: String?, default def: Bool) -> Bool {
        guard
            let v = value?.trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        else { return def }
        return ["1", "true", "yes", "y", "on"].contains(v)
            ? true : ["0", "false", "no", "n", "off"].contains(v) ? false : def
    }

    private static func int(from value: String?, default def: Int) -> Int {
        guard let v = value, let i = Int(v) else { return def }
        return i
    }

    private static func double(from value: String?, default def: Double)
        -> Double
    {
        guard let v = value, let d = Double(v) else { return def }
        return d
    }

    // Pretty-print for debugging
    public var description: String {
        "computeUnits=\(computeUnits), preferANE=\(preferANE), batchSize=\(batchSize), timeout=\(predictionTimeout), lowPrecision=\(allowLowPrecision)"
    }

    // Memberwise initializer (public)
    public init(computeUnits: ComputeUnits,
                preferANE: Bool,
                batchSize: Int,
                predictionTimeout: TimeInterval,
                allowLowPrecision: Bool) {
        self.computeUnits = computeUnits
        self.preferANE = preferANE
        self.batchSize = batchSize
        self.predictionTimeout = predictionTimeout
        self.allowLowPrecision = allowLowPrecision
    }
}

// Example usage in a test:
// let config = CoreMLTestConfig.current(applyingModelName: "YourModelName").modelConfiguration()
// let model = try MLModel(contentsOf: modelURL, configuration: config)
// let batchSize = CoreMLTestConfig.current(applyingModelName: "YourModelName").batchSize
// let timeout = CoreMLTestConfig.current(applyingModelName: "YourModelName").predictionTimeout
