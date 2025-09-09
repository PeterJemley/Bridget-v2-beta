// BaseCoreMLTestCase.swift
// Swift Testing utilities for Core ML tests (no XCTest dependency)

import Foundation
import CoreML
#if canImport(Testing)
import Testing
#endif

struct CoreMLTestSupport {

    // Resolve a test configuration, optionally applying a model name to use model-specific defaults.
    static func config(applying modelName: String? = nil) -> CoreMLTestConfig {
        CoreMLTestConfig.current(applyingModelName: modelName)
    }

    // Convenience to load a model with the resolved MLModelConfiguration.
    // If no config provided, it uses env + defaults (optionally per model).
    static func loadModel(at url: URL, modelName: String? = nil, config: CoreMLTestConfig? = nil) throws -> MLModel {
        let cfg = (config ?? self.config(applying: modelName)).modelConfiguration()
        return try MLModel(contentsOf: url, configuration: cfg)
    }

    // Helpers to access batch size / timeout derived from config.
    static func batchSize(for modelName: String? = nil) -> Int {
        config(applying: modelName).batchSize
    }

    static func predictionTimeout(for modelName: String? = nil) -> TimeInterval {
        config(applying: modelName).predictionTimeout
    }

    // Simple timing helper for measuring blocks in tests.
    // Returns the result and elapsed time in seconds.
    @discardableResult
    static func measure<T>(_ name: String = "prediction", block: () throws -> T) rethrows -> (result: T, elapsed: TimeInterval) {
        let start = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let elapsed = CFAbsoluteTimeGetCurrent() - start
        // With Swift Testing, you can optionally log via print or attach to activities when they’re available.
        // Keeping this lightweight and side-effect free by default.
        return (result, elapsed)
    }
}

/*
Example usage with Swift Testing:

import Testing

@Suite("Image Classifier Inference")
struct ImageClassifierTests {

    @Test("Runs a single inference")
    func testInference() throws {
        // Resolve model URL (adjust bundle lookup as needed)
        let url = Bundle.module.url(forResource: "ImageClassifier", withExtension: "mlmodelc")!
        let model = try CoreMLTestSupport.loadModel(at: url, modelName: "ImageClassifier")

        let batch = CoreMLTestSupport.batchSize(for: "ImageClassifier")
        let timeout = CoreMLTestSupport.predictionTimeout(for: "ImageClassifier")

        // Use `batch` and `timeout` in your test logic...
        #expect(batch > 0)
        _ = timeout
        _ = model
    }

    @Test("Measure prediction time")
    func testMeasure() throws {
        let (_, elapsed) = CoreMLTestSupport.measure("dummy work") {
            // do some work here
            return true
        }
        #expect(elapsed >= 0)
    }
}
*/
