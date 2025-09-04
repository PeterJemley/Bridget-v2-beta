# Dependency/Recursion Workflow for Module Extraction

## Overview

This document outlines the critical dependency/recursion approach for module extraction where **everything following below uses these samples to confirm parity after each module extraction. If outputs change (shapes, counts, ranges), loop back to the module that just changed.**

## 🔄 Core Principle

**Output Parity Must Be Maintained**: After each module extraction, the pipeline must produce identical outputs (shapes, counts, ranges) when processing the golden NDJSON samples. Any deviation triggers an automatic loop-back to the problematic module.

## 🎯 What This Prevents

- **Silent Regressions**: Changes that break functionality without detection
- **Cascading Failures**: One module change breaking downstream modules
- **Data Inconsistencies**: Outputs that don't match expected baselines
- **Performance Degradation**: Unintended performance impacts

## 📋 Workflow Steps

### 1. Pre-Extraction Baseline
```
Golden Samples → Baseline Pipeline → Baseline Metrics
     ↓
Record: shapes, counts, ranges, performance, memory
```

### 2. Module Extraction
```
Extract Module → Refactor Code → Update Dependencies
     ↓
Maintain Interface Compatibility
```

### 3. Post-Extraction Validation
```
Golden Samples → Current Pipeline → Current Metrics
     ↓
PipelineParityValidator.validateParity()
```

### 4. Parity Decision
```
✅ Parity Maintained → Continue to Next Module
❌ Parity Failed → Loop Back to Problematic Module
```

## 🔍 Parity Validation Types

### Shape Validation
- **Output Structure**: File format, record structure, field organization
- **Schema Consistency**: Field names, types, required vs optional fields
- **Data Organization**: How records are grouped, sorted, or structured

**Example Failure**:
```swift
// Before: NDJSON with 12 fields per record
// After: NDJSON with 11 fields per record
// Result: Shape change detected → Loop back to BridgeDataProcessor
```

### Count Validation
- **Total Records**: Exact record count must match baseline
- **Bridge Distribution**: Records per bridge must be identical
- **Time Distribution**: Hourly/minute patterns must match
- **Validation Failures**: Number of rejected records must be identical

**Example Failure**:
```swift
// Before: 8,640 total records (1,440 × 3 bridges × 2)
// After: 8,640 total records but 1,440 × 3 bridges × 1
// Result: Count change detected → Loop back to BridgeDataExporter
```

### Range Validation
- **Numeric Ranges**: Min/max/mean values for numeric fields
- **Categorical Distributions**: Value frequencies for enum fields
- **Statistical Consistency**: Data distributions must match within tolerance

**Example Failure**:
```swift
// Before: cross_k range: 0-100, mean: 45.2
// After: cross_k range: 0-95, mean: 42.1
// Result: Range change detected → Loop back to BridgeDataProcessor
```

## 🛠️ Implementation with PipelineParityValidator

### Basic Usage
```swift
let validator = PipelineParityValidator.shared

// After module extraction, validate parity
let result = try await validator.validateParity(
  baseline: baselineMetrics,
  current: currentOutput,
  sample: goldenSample
)

if !result.isParity {
  // 🔄 LOOP BACK REQUIRED
  print("Parity failed: \(result.failureReason)")
  print("Affected module: \(result.affectedModule)")
  print("Guidance: \(result.loopbackGuidance)")
  
  // Take action based on failure
  await handleParityFailure(result)
}
```

### Automatic Loop-back Detection
```swift
func handleParityFailure(_ result: ParityValidationResult) async {
  switch result.confidence {
  case 0.8...1.0:
    // High confidence - clear module to fix
    await revertModule(result.affectedModule!)
    await reExtractModule(result.affectedModule!)
    
  case 0.5..<0.8:
    // Medium confidence - investigate further
    await investigateRelatedModules(result.detectedChanges)
    
  default:
    // Low confidence - manual investigation needed
    await manualInvestigation(result)
  }
}
```

## 📊 Module Impact Analysis

### BridgeDataProcessor Changes
**Typical Impact**: Shape, Range, Validation
- **Shape**: Output structure, field counts
- **Range**: Data transformations, calculations
- **Validation**: Business rule enforcement

**Loop-back Trigger**: Critical shape or range changes

### BridgeDataExporter Changes
**Typical Impact**: Shape, Count, Schema
- **Shape**: File format, record structure
- **Count**: Record filtering, deduplication
- **Schema**: Field definitions, data types

**Loop-back Trigger**: Critical count or schema changes

### BridgeDataService Changes
**Typical Impact**: Count, Performance
- **Count**: Data ingestion, filtering
- **Performance**: Caching, network optimization

**Loop-back Trigger**: Critical count changes

### MLPipelineBackgroundManager Changes
**Typical Impact**: Performance, Range
- **Performance**: Task orchestration, timing
- **Range**: Data processing coordination

**Loop-back Trigger**: Performance regressions

## 🔄 Loop-back Scenarios

### Scenario 1: Critical Shape Change
```
1. Extract BridgeDataProcessor
2. Run golden samples through pipeline
3. PipelineParityValidator detects shape change
4. Analysis: "BridgeDataProcessor or BridgeDataExporter"
5. Loop back: Revert BridgeDataProcessor changes
6. Re-extract with more conservative approach
7. Re-validate parity
```

### Scenario 2: Count Mismatch
```
1. Extract BridgeDataExporter
2. Run golden samples through pipeline
3. PipelineParityValidator detects count change
4. Analysis: "BridgeDataService or ProbeTickDataService"
5. Loop back: Revert BridgeDataExporter changes
6. Investigate data flow dependencies
7. Re-extract with proper interface preservation
```

### Scenario 3: Performance Regression
```
1. Extract MLPipelineBackgroundManager
2. Run golden samples through pipeline
3. PipelineParityValidator detects performance change
4. Analysis: "Multiple modules - performance regression detected"
5. Loop back: Revert MLPipelineBackgroundManager changes
6. Profile performance impact
7. Re-extract with performance monitoring
```

## 📈 Monitoring and Alerting

### Real-time Parity Monitoring
```swift
// During module extraction, monitor continuously
Task {
  for try await extractionStep in moduleExtractionSteps {
    let parityResult = await validateParity()
    
    if !parityResult.isParity {
      // Immediate alert and loop-back
      await alertParityFailure(parityResult)
      await triggerLoopback(parityResult.affectedModule)
    }
  }
}
```

### Automated Loop-back Triggers
```swift
func triggerLoopback(_ moduleName: String) async {
  // 1. Stop current extraction
  await stopModuleExtraction()
  
  // 2. Revert module changes
  await revertModuleChanges(moduleName)
  
  // 3. Restore baseline state
  await restoreBaselineState()
  
  // 4. Notify developers
  await notifyParityFailure(moduleName)
  
  // 5. Provide guidance for next attempt
  await provideLoopbackGuidance(moduleName)
}
```

## 🎯 Success Criteria

### Module Extraction Success
- ✅ **Parity Maintained**: All golden samples produce identical outputs
- ✅ **Performance Preserved**: Within 10% of baseline timing
- ✅ **Memory Efficient**: Within 20% of baseline memory usage
- ✅ **Interface Compatible**: No breaking changes to public APIs

### Loop-back Success
- ✅ **Quick Detection**: Parity failures detected within 1 pipeline run
- ✅ **Accurate Analysis**: Correct module identification with >80% confidence
- ✅ **Clear Guidance**: Actionable loop-back instructions
- ✅ **Minimal Disruption**: Quick restoration to working state

## 🚨 Common Pitfalls

### 1. Interface Changes
```swift
// ❌ DON'T: Change public method signatures
func processData(_ data: Data) -> [BridgeStatusModel]

// ✅ DO: Maintain exact interface compatibility
func processData(_ data: Data) -> [BridgeStatusModel]
```

### 2. Data Transformations
```swift
// ❌ DON'T: Modify data during extraction
let processedData = data.map { record in
  // Don't change record structure here
  return record
}

// ✅ DO: Extract module without changing data flow
let extractedModule = ExtractedModule()
return extractedModule.process(data)
```

### 3. Performance Assumptions
```swift
// ❌ DON'T: Assume performance will improve
// Performance may degrade during extraction

// ✅ DO: Monitor and validate performance parity
let performanceResult = validatePerformanceParity()
if !performanceResult.isParity {
  await handlePerformanceRegression()
}
```

## 📚 Best Practices

### 1. Incremental Extraction
- Extract one module at a time
- Validate parity after each extraction
- Don't extract multiple modules simultaneously

### 2. Interface Preservation
- Maintain exact public API compatibility
- Use adapter patterns if interfaces must change
- Document any interface modifications

### 3. Comprehensive Testing
- Test with all golden samples (weekday, weekend, DST)
- Validate edge cases and error conditions
- Monitor performance and memory usage

### 4. Rollback Strategy
- Keep baseline code in version control
- Implement quick rollback mechanisms
- Maintain rollback documentation

## 🔮 Future Enhancements

### Automated Module Extraction
- AI-assisted module boundary detection
- Automatic interface compatibility checking
- Predictive parity failure detection

### Enhanced Validation
- Machine learning-based change detection
- Semantic similarity analysis
- Cross-sample consistency validation

### Continuous Monitoring
- Real-time parity validation during development
- Automated regression prevention
- Performance trend analysis

## 📝 Summary

The dependency/recursion workflow ensures that module extraction maintains output parity by:

1. **Establishing Baselines**: Golden samples provide known good outputs
2. **Validating Parity**: PipelineParityValidator detects any changes
3. **Looping Back**: Automatic return to problematic modules
4. **Maintaining Quality**: No regressions slip through

This approach makes module extraction safe, predictable, and maintainable while preserving the integrity of the Bridget ML pipeline.
