import Testing
import CoreML
import Foundation

/// Base test class for Core ML tests using Swift Testing
/// Provides automatic configuration loading and convenient test helpers
@MainActor
open class BaseCoreMLTest {
    
    // MARK: - Configuration
    
    /// Current Core ML test configuration from environment variables
    public let config = CoreMLTestConfig.current
    
    /// Model name for applying model-specific defaults (override in subclasses)
    /// Provide the model's logical name (e.g., "BridgePredictor") to apply defaults from CoreMLTestConfig.modelProfiles
    open var modelNameForDefaults: String? {
        return nil
    }
    
    /// Model-specific configuration (combines environment variables with model defaults)
    public var modelConfig: CoreMLTestConfig {
        return CoreMLTestConfig.current(applyingModelName: modelNameForDefaults)
    }
    
    // MARK: - Convenience Properties
    
    /// Batch size from current configuration
    public var batchSize: Int {
        return modelConfig.batchSize
    }
    
    /// Prediction timeout from current configuration
    public var predictionTimeout: TimeInterval {
        return modelConfig.predictionTimeout
    }
    
    /// Whether low precision is allowed
    public var allowLowPrecision: Bool {
        return modelConfig.allowLowPrecision
    }
    
    /// Whether to prefer Apple Neural Engine
    public var preferANE: Bool {
        return modelConfig.preferANE
    }
    
    /// Compute units from current configuration
    public var computeUnits: CoreMLTestConfig.ComputeUnits {
        return modelConfig.computeUnits
    }
    
    // MARK: - Model Loading
    
    /// Loads an MLModel with the current configuration
    /// - Parameter url: URL to the model file
    /// - Returns: Configured MLModel
    /// - Throws: Error if model loading fails
    public func loadModel(at url: URL) throws -> MLModel {
        let mlConfig = modelConfig.modelConfiguration()
        return try MLModel(contentsOf: url, configuration: mlConfig)
    }
    
    /// Loads an MLModel from the test bundle with the current configuration
    /// - Parameters:
    ///   - name: Model name (without extension)
    ///   - fileExtension: Model file extension (default: "mlmodelc")
    /// - Returns: Configured MLModel
    /// - Throws: Error if model loading fails
    public func loadModel(named name: String, fileExtension: String = "mlmodelc") throws -> MLModel {
        guard let url = Bundle.module.url(forResource: name, withExtension: fileExtension) else {
            throw TestError.modelNotFound(name: name, fileExtension: fileExtension)
        }
        return try loadModel(at: url)
    }
    
    // MARK: - Test Helpers
    
    /// Asserts that the model loads successfully with current configuration
    /// - Parameters:
    ///   - name: Model name
    ///   - fileExtension: Model file extension
    public func assertModelLoads(named name: String, fileExtension: String = "mlmodelc") {
        do {
            _ = try loadModel(named: name, fileExtension: fileExtension)
            #expect(true, "Model should load successfully")
        } catch {
            Issue.record("Failed to load model '\(name)': \(error)")
        }
    }
    
    /// Asserts that a prediction completes within the configured timeout
    /// - Parameter prediction: Prediction closure to execute
    /// - Returns: Result of the prediction
    /// - Throws: Error if prediction fails or times out
    public func assertPredictionCompletesWithinTimeout<T>(_ prediction: () throws -> T) throws -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try prediction()
        let elapsedTime = CFAbsoluteTimeGetCurrent() - startTime
        
        #expect(elapsedTime < predictionTimeout,
                "Prediction took \(elapsedTime)s, expected < \(predictionTimeout)s")
        
        return result
    }
    
    /// Asserts that batch size is within reasonable bounds
    public func assertValidBatchSize() {
        #expect(batchSize > 0, "Batch size should be positive")
        #expect(batchSize <= 128, "Batch size should be reasonable for testing")
    }
    
    // MARK: - Setup and Teardown
    
    /// Called before each test method
    open func setUp() async throws {
        // Log current configuration for debugging
        print("🧪 CoreMLTestConfig: \(modelConfig)")
        
        // Validate configuration
        assertValidBatchSize()
    }
    
    /// Called after each test method
    open func tearDown() async throws {
        // Add any cleanup if needed
    }
}

// MARK: - Test Errors

public enum TestError: Error, LocalizedError {
    case modelNotFound(name: String, fileExtension: String)
    case predictionTimeout(timeout: TimeInterval)
    case invalidConfiguration(reason: String)
    
    public var errorDescription: String? {
        switch self {
        case .modelNotFound(let name, let fileExtension):
            return "Model '\(name).\(fileExtension)' not found in test bundle"
        case .predictionTimeout(let timeout):
            return "Prediction timed out after \(timeout) seconds"
        case .invalidConfiguration(let reason):
            return "Invalid configuration: \(reason)"
        }
    }
}

// MARK: - Bundle Extension

private extension Bundle {
    /// Test bundle for loading resources
    static var module: Bundle {
        return Bundle(for: BaseCoreMLTest.self)
    }
}

// MARK: - Swift Testing Tags

/// Tags for categorizing Core ML tests
public enum CoreMLTestTag: String, CaseIterable {
    case unit = "unit"
    case integration = "integration"
    case performance = "performance"
    case coreml = "coreml"
    case cpuOnly = "cpu-only"
    case gpu = "gpu"
    case ane = "ane"
    case lowPrecision = "low-precision"
    case ci = "ci"
}

// MARK: - Test Configuration Helpers

/// Helper functions for Swift Testing Core ML tests
public enum CoreMLTestHelpers {
    /// Computes tag strings to be used with the @Test trait `.tags(...)`.
    /// Usage:
    ///   @Test("My test", .tags(CoreMLTestHelpers.computedTags()))
    ///   func testSomething() async throws { ... }
    public static func computedTags(additional tags: [CoreMLTestTag] = []) -> [String] {
        let config = CoreMLTestConfig.current
        var all = tags
        
        // Add configuration-based tags
        switch config.computeUnits {
        case .cpu_only:
            all.append(.cpuOnly)
        case .cpu_and_gpu:
            all.append(.gpu)
        case .all:
            all.append(.ane)
        }
        
        if config.allowLowPrecision {
            all.append(.lowPrecision)
        }
        
        all.append(.coreml)
        return all.map { $0.rawValue }
    }
    
    /// Runs a test body with no attempt to dynamically construct a Test.
    /// Call this from inside an @Test function if you want a central hook.
    public static func run<T>(_ body: @escaping () async throws -> T) async rethrows -> T {
        try await body()
    }
}
