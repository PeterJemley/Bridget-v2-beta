# Swift Testing Core ML Configuration

## Overview

This document describes the Swift Testing-based system for Core ML testing with environment variable configuration to avoid resource contention and provide better test organization.

## Core Components

### CoreMLTestConfig.swift

Environment variable reader that provides MLModelConfiguration settings:

```swift
// Get current configuration
let config = CoreMLTestConfig.current

// Create MLModelConfiguration
let mlConfig = config.createMLModelConfiguration()

// Model-specific configuration
let bridgeConfig = CoreMLTestConfig.forModel(.bridgePredictor)
```

### BaseCoreMLTest.swift

Base class for Core ML tests using Swift Testing:

```swift
final class MyCoreMLTests: BaseCoreMLTest {
    override var modelNameForDefaults: CoreMLTestConfig.ModelProfile? {
        return .bridgePredictor
    }
    
    @Test("Model loading test")
    func testModelLoading() async throws {
        let model = try loadModel(named: "BridgePredictor")
        #expect(model != nil)
    }
    
    @Test("Prediction performance test")
    func testPrediction() async throws {
        let result = try assertPredictionCompletesWithinTimeout {
            // Your prediction code here
            return predictionResult
        }
        #expect(result != nil)
    }
}
```

## Environment Variable Configuration

### Available Configurations

| Configuration | Compute Units | Batch Size | Timeout | Low Precision | ANE | Use Case |
|---------------|---------------|------------|---------|---------------|-----|----------|
| `CPU_ONLY` | CPU Only | 32 | 60s | No | No | Standard unit tests |
| `CPU_ONLY_LOW_PRECISION` | CPU Only | 16 | 30s | Yes | No | Fast unit tests |
| `CPU_AND_GPU` | CPU + GPU | 32 | 60s | No | No | Integration tests |
| `CPU_AND_GPU_LOW_PRECISION` | CPU + GPU | 32 | 45s | Yes | No | Fast integration tests |
| `ALL` | All Units | 32 | 60s | No | Yes | Performance tests |
| `ALL_LOW_PRECISION` | All Units | 32 | 45s | Yes | Yes | Fast performance tests |
| `CI` | CPU Only | 16 | 120s | Yes | No | CI/CD environments |

### Environment Variables

- **`ML_BATCH_SIZE`**: Batch size for ML operations
- **`ML_PREDICTION_TIMEOUT`**: Prediction timeout in seconds
- **`ML_ALLOW_LOW_PRECISION`**: Whether to allow low precision operations
- **`ML_PREFER_ANE`**: Whether to prefer Apple Neural Engine
- **`ML_COMPUTE_UNITS`**: Compute units (`CPU_ONLY`, `CPU_AND_GPU`, `ALL`)

## Usage

### In Xcode

1. **Set Environment Variables**: Edit Scheme → Test → Arguments → Environment Variables
2. **Add Variables**: Add the ML_* variables with appropriate values
3. **Run Tests**: Use Product > Test or Cmd+U

### Command Line

```bash
# Run with specific configuration
env ML_COMPUTE_UNITS=CPU_ONLY ML_BATCH_SIZE=16 \
  xcodebuild -project Bridget.xcodeproj \
  -scheme Bridget \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
  test

# Run all configurations sequentially
./Scripts/run_coreml_tests.sh
```

### Swift Testing Tags

Use tags to categorize tests:

```swift
@Test("Core ML unit test", tags: [.unit, .coreml])
func testModelLoading() async throws {
    let config = CoreMLTestConfig.current
    // Test code...
}

@Test("Core ML performance test", tags: [.performance, .coreml]) 
func testPredictionPerformance() async throws {
    let config = CoreMLTestConfig.current
    // Test code...
}
```

## CI Integration

### Automated Test Execution

The `run_coreml_tests.sh` script runs all configurations sequentially:

```bash
#!/usr/bin/env bash
./Scripts/run_coreml_tests.sh
```

#### Script Features

- **Sequential Execution**: Prevents resource contention
- **Environment Variables**: Sets appropriate ML configuration per run
- **Separate Artifacts**: Each configuration gets its own result bundle
- **Comprehensive Logging**: Detailed execution logs
- **Error Handling**: Continues on failure, reports summary

#### Execution Strategy

| Configuration | Purpose | Resource Usage |
|---------------|---------|----------------|
| CPU_ONLY | Unit tests | Minimal |
| CPU_AND_GPU | Integration tests | Moderate |
| ALL | Performance tests | Maximum |
| CI | CI/CD environments | Optimized |

### Artifact Management

Results are stored in timestamped directories:

```
TestResults/
└── 20241206-143022/
    ├── CPU_ONLY.xcresult
    ├── CPU_AND_GPU.xcresult
    ├── ALL.xcresult
    └── CI.xcresult
```

## Best Practices

### Test Organization

1. **Inherit from BaseCoreMLTest**: Automatic configuration loading
2. **Use Swift Testing Tags**: Categorize tests by type
3. **Set Model Profiles**: Use model-specific defaults when available
4. **Validate Configuration**: Use built-in assertion helpers

### Performance Considerations

1. **Start with CPU_ONLY**: Fastest execution for development
2. **Use Low Precision Variants**: Faster execution for non-critical tests
3. **Avoid ALL Configuration**: Only for performance-critical tests
4. **Clean Up Resources**: Use defer blocks for cleanup

### CI/CD Integration

1. **Use CI Configuration**: Optimized for CI environments
2. **Run Sequentially**: Avoid resource contention
3. **Collect Artifacts**: Store result bundles for analysis
4. **Monitor Timeouts**: Adjust timeouts based on CI performance

## Migration from XCTest

### Before (XCTest)
```swift
class MyTests: XCTestCase {
    func testModel() throws {
        let config = MLModelConfiguration()
        config.computeUnits = .cpuOnly
        let model = try MLModel(contentsOf: url, configuration: config)
        // Test code...
    }
}
```

### After (Swift Testing)
```swift
final class MyTests: BaseCoreMLTest {
    @Test("Model test")
    func testModel() async throws {
        let model = try loadModel(at: url)
        // Test code...
    }
}
```

## Troubleshooting

### Common Issues

#### Resource Contention
- **Symptom**: Tests stall or fail randomly
- **Solution**: Use CPU_ONLY configuration or run configurations sequentially

#### Timeout Failures
- **Symptom**: Predictions timeout
- **Solution**: Increase `ML_PREDICTION_TIMEOUT` or use faster configuration

#### Model Loading Errors
- **Symptom**: Models fail to load
- **Solution**: Check model paths and bundle resources

#### Configuration Not Applied
- **Symptom**: Environment variables not read
- **Solution**: Verify environment variable names and values

### Debug Commands

```bash
# Check environment variables
env | grep ML_

# Verify configuration
swift test --list

# Run single configuration
env ML_COMPUTE_UNITS=CPU_ONLY swift test
```

## Future Enhancements

### Planned Improvements

- **Dynamic Configuration**: Runtime configuration based on device capabilities
- **Performance Profiling**: Built-in performance measurement
- **Test Categorization**: Automatic test categorization based on tags
- **Parallel Configuration Execution**: Safe parallel execution of non-conflicting configurations

### Configuration Profiles

- **Device-Specific**: Different configurations for different devices
- **Model-Specific**: Automatic configuration based on model type
- **Environment-Specific**: Different settings for dev/staging/production


