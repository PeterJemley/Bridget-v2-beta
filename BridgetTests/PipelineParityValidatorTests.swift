//
//  PipelineParityValidatorTests.swift
//  BridgetTests
//
//  Purpose: Comprehensive unit tests for PipelineParityValidator
//  Dependencies: PipelineParityValidator, test data fixtures
//  Test Coverage:
//    - Golden path: parity passes when no code changed
//    - Shape drift: remove one feature → expect .critical change for field_count
//    - Count drift: drop 2% of ticks for one bridge → .warning count change
//    - Range drift: scale one feature by +10% → .warning on that field's ValueRange
//    - Schema drift: rename a field → .critical with schema diff details
//    - Perf drift: inject a deliberate 20% slow-down → .warning/.critical based on config

@testable import Bridget
import Testing

@Suite("Pipeline Parity Validator Tests")
struct PipelineParityValidatorTests {
  private var validator: PipelineParityValidator!
  private var baselineMetrics: BaselineMetrics!
  private var currentOutput: CurrentOutput!
  private var goldenSample: GoldenSample!

  private mutating func setUp() async throws {
    // Use default configuration for most tests
    validator = PipelineParityValidator(config: .default)

    // Create baseline test data
    baselineMetrics = createBaselineMetrics()

    // Create golden sample
    goldenSample = createGoldenSample()
  }

  // MARK: - Test Data Creation

  private func createBaselineMetrics() -> BaselineMetrics {
    let timeDistribution = TimeDistribution(hourlyDistribution: createHourlyDistribution(),
                                            description: "Baseline 24-hour distribution")

    let fieldRanges: [String: ValueRange] = [
      "cross_k": ValueRange(min: 0, max: 100, mean: 45.2, description: "Baseline cross_k range"),
      "cross_n": ValueRange(min: 1, max: 200, mean: 98.7, description: "Baseline cross_n range"),
      "via_penalty_sec": ValueRange(min: 0, max: 300, mean: 45.8, description: "Baseline penalty range"),
      "gate_anom": ValueRange(min: 0, max: 1, mean: 0.5, description: "Baseline anomaly range"),
      "alternates_total": ValueRange(min: 1, max: 5, mean: 3.2, description: "Baseline alternates range"),
    ]

    let fieldDistributions: [String: FieldDistribution] = [
      "bridge_id": FieldDistribution(values: ["1": 2880, "2": 2880, "3": 2880],
                                     description: "Baseline bridge distribution"),
      "via_routable": FieldDistribution(values: ["0": 4320, "1": 4320],
                                        description: "Baseline routable distribution"),
      "open_label": FieldDistribution(values: ["0": 6480, "1": 2160],
                                      description: "Baseline open label distribution"),
    ]

    let schema = DataSchema(fields: ["v", "ts_utc", "bridge_id", "cross_k", "cross_n", "via_routable", "via_penalty_sec", "gate_anom", "alternates_total", "alternates_avoid_span", "free_eta_sec", "via_eta_sec", "open_label"],
                            fieldTypes: [
                              "v": "Int", "ts_utc": "String", "bridge_id": "Int", "cross_k": "Int16", "cross_n": "Int16",
                              "via_routable": "Int", "via_penalty_sec": "Int32", "gate_anom": "Double", "alternates_total": "Int16",
                              "alternates_avoid_span": "Int16", "free_eta_sec": "Int32?", "via_eta_sec": "Int32?", "open_label": "Int",
                            ])

    let stageTimings: [String: TimeInterval] = [
      "parse": 0.1,
      "features": 0.5,
      "arrays": 0.3,
      "train": 1.0,
      "validate": 0.2,
    ]

    let memoryMetrics = MemoryMetrics(peakMemory: 150.0,
                                      averageMemory: 120.0,
                                      memoryEfficiency: 0.8)

    return BaselineMetrics(outputStructure: "NDJSON",
                           fieldCount: 13,
                           bridgeRecordCounts: ["1": 2880, "2": 2880, "3": 2880],
                           timeDistribution: timeDistribution,
                           fieldRanges: fieldRanges,
                           fieldDistributions: fieldDistributions,
                           pipelineTime: 2.1,
                           peakMemory: 150.0,
                           schema: schema,
                           schemaHash: "baseline_schema_hash_12345",
                           stageTimings: stageTimings,
                           memoryMetrics: memoryMetrics,
                           deterministicSeedUsed: true)
  }

  private func createCurrentOutput() -> CurrentOutput {
    // Start with identical baseline data
    let timeDistribution = TimeDistribution(hourlyDistribution: createHourlyDistribution(),
                                            description: "Current 24-hour distribution")

    let fieldRanges: [String: ValueRange] = [
      "cross_k": ValueRange(min: 0, max: 100, mean: 45.2, description: "Current cross_k range"),
      "cross_n": ValueRange(min: 1, max: 200, mean: 98.7, description: "Current cross_n range"),
      "via_penalty_sec": ValueRange(min: 0, max: 300, mean: 45.8, description: "Current penalty range"),
      "gate_anom": ValueRange(min: 0, max: 1, mean: 0.5, description: "Current anomaly range"),
      "alternates_total": ValueRange(min: 1, max: 5, mean: 3.2, description: "Current alternates range"),
    ]

    let fieldDistributions: [String: FieldDistribution] = [
      "bridge_id": FieldDistribution(values: ["1": 2880, "2": 2880, "3": 2880],
                                     description: "Current bridge distribution"),
      "via_routable": FieldDistribution(values: ["0": 4320, "1": 4320],
                                        description: "Current routable distribution"),
      "open_label": FieldDistribution(values: ["0": 6480, "1": 2160],
                                      description: "Current open label distribution"),
    ]

    let schema = DataSchema(fields: ["v", "ts_utc", "bridge_id", "cross_k", "cross_n", "via_routable", "via_penalty_sec", "gate_anom", "alternates_total", "alternates_avoid_span", "free_eta_sec", "via_eta_sec", "open_label"],
                            fieldTypes: [
                              "v": "Int", "ts_utc": "String", "bridge_id": "Int", "cross_k": "Int16", "cross_n": "Int16",
                              "via_routable": "Int", "via_penalty_sec": "Int32", "gate_anom": "Double", "alternates_total": "Int16",
                              "alternates_avoid_span": "Int16", "free_eta_sec": "Int32?", "via_eta_sec": "Int32?", "open_label": "Int",
                            ])

    let stageTimings: [String: TimeInterval] = [
      "parse": 0.1,
      "features": 0.5,
      "arrays": 0.3,
      "train": 1.0,
      "validate": 0.2,
    ]

    let memoryMetrics = MemoryMetrics(peakMemory: 150.0,
                                      averageMemory: 120.0,
                                      memoryEfficiency: 0.8)

    return CurrentOutput(outputStructure: "NDJSON",
                         fieldCount: 13,
                         totalRecords: 8640,
                         bridgeRecordCounts: ["1": 2880, "2": 2880, "3": 2880],
                         timeDistribution: timeDistribution,
                         fieldRanges: fieldRanges,
                         fieldDistributions: fieldDistributions,
                         pipelineTime: 2.1,
                         peakMemory: 150.0,
                         schema: schema,
                         schemaHash: "baseline_schema_hash_12345",
                         stageTimings: stageTimings,
                         memoryMetrics: memoryMetrics)
  }

  private func createGoldenSample() -> GoldenSample {
    return GoldenSample(name: "test_sample",
                        expectedRecordCount: 8640,
                        bridgeIds: ["1", "2", "3"],
                        dataQuality: DataQuality(validationFailures: 0,
                                                 correctedRows: 0,
                                                 completeness: 1.0))
  }

  private func createHourlyDistribution() -> [Int: Int] {
    var distribution: [Int: Int] = [:]
    for hour in 0 ..< 24 {
      distribution[hour] = 360 // 8640 records / 24 hours
    }
    return distribution
  }

  // MARK: - Golden Path Tests

  @Test("Parity passes when no code changed")
  mutating func parityPassesWhenNoCodeChanged() async throws {
    try await setUp()

    // Given: Identical baseline and current outputs
    currentOutput = createCurrentOutput()

    // When: Validating parity
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Parity should pass
    #expect(result.isParity == true, "Parity should pass when outputs are identical")
    #expect(result.failureReason == nil, "No failure reason should be present")
    #expect(result.affectedModule == nil, "No affected module should be identified")
    #expect(result.confidence == 1.0, "Confidence should be 100% for identical outputs")
    #expect(result.detectedChanges.isEmpty == true, "No changes should be detected")
  }

  // MARK: - Shape Drift Tests

  @Test("Shape drift removes one feature expects critical change")
  mutating func shapeDriftRemovesOneFeatureExpectsCriticalChange() async throws {
    try await setUp()

    // Given: Current output missing one field
    currentOutput = createCurrentOutput()
    currentOutput = CurrentOutput(outputStructure: "NDJSON",
                                  fieldCount: 12, // Reduced from 13
                                  totalRecords: 8640,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: currentOutput.fieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: currentOutput.pipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: DataSchema(fields: ["v", "ts_utc", "bridge_id", "cross_k", "cross_n", "via_routable", "via_penalty_sec", "gate_anom", "alternates_total", "alternates_avoid_span", "free_eta_sec", "open_label"], // Missing "via_eta_sec"
                                                     fieldTypes: [
                                                       "v": "Int", "ts_utc": "String", "bridge_id": "Int", "cross_k": "Int16", "cross_n": "Int16",
                                                       "via_routable": "Int", "via_penalty_sec": "Int32", "gate_anom": "Double", "alternates_total": "Int16",
                                                       "alternates_avoid_span": "Int16", "free_eta_sec": "Int32?", "open_label": "Int",
                                                     ]),
                                  schemaHash: "modified_schema_hash_67890",
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Parity should fail with critical shape change
    #expect(result.isParity == false, "Parity should fail when field count changes")
    #expect(result.failureReason != nil, "Failure reason should be present")
    #expect(result.affectedModule == .bridgeDataProcessor, "BridgeDataProcessor should be identified")

    // Check for specific shape changes
    let shapeChanges = result.detectedChanges.filter { $0.changeType == .shape }
    #expect(shapeChanges.isEmpty == false, "Shape changes should be detected")

    let fieldCountChange = shapeChanges.first { $0.affectedField == "field_count" }
    #expect(fieldCountChange != nil, "Field count change should be detected")
    #expect(fieldCountChange?.severity == .critical, "Field count change should be critical")

    // Check metadata
    #expect(fieldCountChange?.metadata["baseline_fields"] == "13")
    #expect(fieldCountChange?.metadata["current_fields"] == "12")
    #expect(fieldCountChange?.metadata["field_difference"] == "-1")
  }

  // MARK: - Count Drift Tests

  @Test("Count drift drops 2% of ticks for one bridge expects warning count change")
  mutating func countDriftDrops2PercentOfTicksForOneBridgeExpectsWarningCountChange() async throws {
    try await setUp()

    // Given: Current output with 2% fewer records for bridge 1
    currentOutput = createCurrentOutput()
    let reducedBridge1Count = Int(Double(2880) * 0.98) // 2% reduction
    currentOutput = CurrentOutput(outputStructure: currentOutput.outputStructure,
                                  fieldCount: currentOutput.fieldCount,
                                  totalRecords: 8640 - (2880 - reducedBridge1Count), // Adjusted total
                                  bridgeRecordCounts: ["1": reducedBridge1Count, "2": 2880, "3": 2880],
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: currentOutput.fieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: currentOutput.pipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: currentOutput.schema,
                                  schemaHash: currentOutput.schemaHash,
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity with relaxed config
    let relaxedValidator = PipelineParityValidator(config: .relaxed)
    let result = try await relaxedValidator.validateParity(baseline: baselineMetrics,
                                                           current: currentOutput,
                                                           sample: goldenSample)

    // Then: Parity should fail with count change
    #expect(result.isParity == false, "Parity should fail when record counts differ")

    // Check for specific count changes
    let countChanges = result.detectedChanges.filter { $0.changeType == .count }
    #expect(countChanges.isEmpty == false, "Count changes should be detected")

    let bridge1CountChange = countChanges.first { $0.affectedField == "bridge_1_records" }
    #expect(bridge1CountChange != nil, "Bridge 1 count change should be detected")

    // Check metadata
    #expect(bridge1CountChange?.metadata["bridge_id"] == "1")
    #expect(bridge1CountChange?.metadata["baseline_count"] == "2880")
    #expect(bridge1CountChange?.metadata["current_count"] == "\(reducedBridge1Count)")

    // Verify relative delta calculation
    let relativeDelta = Double(bridge1CountChange?.metadata["relative_delta"] ?? "0") ?? 0
    #expect(relativeDelta == 0.02, "Relative delta should be approximately 2%")
  }

  // MARK: - Range Drift Tests

  @Test("Range drift scales one feature by 10% expects warning on value range")
  mutating func rangeDriftScalesOneFeatureBy10PercentExpectsWarningOnValueRange() async throws {
    try await setUp()

    // Given: Current output with cross_k scaled by +10%
    currentOutput = createCurrentOutput()
    let scaledFieldRanges: [String: ValueRange] = [
      "cross_k": ValueRange(min: 0, max: 110, mean: 49.7, description: "Scaled cross_k range"), // +10%
      "cross_n": ValueRange(min: 1, max: 200, mean: 98.7, description: "Current cross_n range"),
      "via_penalty_sec": ValueRange(min: 0, max: 300, mean: 45.8, description: "Current penalty range"),
      "gate_anom": ValueRange(min: 0, max: 1, mean: 0.5, description: "Current anomaly range"),
      "alternates_total": ValueRange(min: 1, max: 5, mean: 3.2, description: "Current alternates range"),
    ]

    currentOutput = CurrentOutput(outputStructure: currentOutput.outputStructure,
                                  fieldCount: currentOutput.fieldCount,
                                  totalRecords: currentOutput.totalRecords,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: scaledFieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: currentOutput.pipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: currentOutput.schema,
                                  schemaHash: currentOutput.schemaHash,
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Parity should fail with range change
    #expect(result.isParity == false, "Parity should fail when value ranges differ")

    // Check for specific range changes
    let rangeChanges = result.detectedChanges.filter { $0.changeType == .range }
    #expect(rangeChanges.isEmpty == false, "Range changes should be detected")

    let crossKRangeChange = rangeChanges.first { $0.affectedField == "cross_k" }
    #expect(crossKRangeChange != nil, "cross_k range change should be detected")
    #expect(crossKRangeChange?.severity == .major, "Range change should be major")

    // Check metadata
    #expect(crossKRangeChange?.metadata["baseline_range"] == "min:0.0, max:100.0, mean:45.2")
    #expect(crossKRangeChange?.metadata["current_range"] == "min:0.0, max:110.0, mean:49.7")
    #expect(crossKRangeChange?.metadata["tolerance"] == "0.05")
  }

  // MARK: - Schema Drift Tests

  @Test("Schema drift renames field expects critical with schema diff details")
  mutating func schemaDriftRenamesFieldExpectsCriticalWithSchemaDiffDetails() async throws {
    try await setUp()

    // Given: Current output with renamed field
    currentOutput = createCurrentOutput()
    let renamedSchema = DataSchema(fields: ["v", "ts_utc", "bridge_id", "cross_k", "cross_n", "via_routable", "via_penalty_sec", "gate_anom", "alternates_total", "alternates_avoid_span", "free_eta_sec", "via_eta_sec", "open_label"],
                                   fieldTypes: [
                                     "v": "Int", "ts_utc": "String", "bridge_id": "Int", "cross_k": "Int16", "cross_n": "Int16",
                                     "via_routable": "Int", "via_penalty_sec": "Int32", "gate_anom": "Double", "alternates_total": "Int16",
                                     "alternates_avoid_span": "Int16", "free_eta_sec": "Int32?", "via_eta_sec": "Int32?", "open_label": "Int",
                                   ])

    currentOutput = CurrentOutput(outputStructure: currentOutput.outputStructure,
                                  fieldCount: currentOutput.fieldCount,
                                  totalRecords: currentOutput.totalRecords,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: currentOutput.fieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: currentOutput.pipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: renamedSchema,
                                  schemaHash: "renamed_schema_hash_11111",
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Parity should fail with schema change
    #expect(result.isParity == false, "Parity should fail when schema differs")

    // Check for specific schema changes
    let schemaChanges = result.detectedChanges.filter { $0.changeType == .schema }
    #expect(schemaChanges.isEmpty == false, "Schema changes should be detected")

    let schemaHashChange = schemaChanges.first { $0.affectedField == "schema_hash" }
    #expect(schemaHashChange != nil, "Schema hash change should be detected")
    #expect(schemaHashChange?.severity == .critical, "Schema hash change should be critical")

    // Check metadata
    #expect(schemaHashChange?.metadata["baseline_hash"] == "baseline_schema_hash_12345")
    #expect(schemaHashChange?.metadata["current_hash"] == "renamed_schema_hash_11111")
    #expect(schemaHashChange?.metadata["hash_difference"] == "Schema structure has changed")
  }

  // MARK: - Performance Drift Tests

  @Test("Performance drift injects 20% slowdown expects warning based on config")
  mutating func performanceDriftInjects20PercentSlowdownExpectsWarningBasedOnConfig() async throws {
    try await setUp()
    // Given: Current output with 20% slower pipeline time
    currentOutput = createCurrentOutput()
    let slowerPipelineTime = baselineMetrics.pipelineTime * 1.2 // 20% slower

    currentOutput = CurrentOutput(outputStructure: currentOutput.outputStructure,
                                  fieldCount: currentOutput.fieldCount,
                                  totalRecords: currentOutput.totalRecords,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: currentOutput.fieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: slowerPipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: currentOutput.schema,
                                  schemaHash: currentOutput.schemaHash,
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity with default config (10% tolerance)
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Parity should fail with performance change
    #expect(result.isParity == false, "Parity should fail when performance differs beyond tolerance")

    // Check for specific performance changes
    let performanceChanges = result.detectedChanges.filter { $0.changeType == .performance }
    #expect(performanceChanges.isEmpty == false, "Performance changes should be detected")

    let pipelineTimeChange = performanceChanges.first { $0.affectedField == "pipeline_time" }
    #expect(pipelineTimeChange != nil, "Pipeline time change should be detected")
    #expect(pipelineTimeChange?.severity == .minor, "Performance change should be minor")

    // Check metadata
    #expect(pipelineTimeChange?.metadata["baseline_time"] == "2.1")
    #expect(pipelineTimeChange?.metadata["current_time"] == "\(slowerPipelineTime)")
    #expect(pipelineTimeChange?.metadata["tolerance"] == "0.1")

    // Verify relative change calculation
    let relativeChange = Double(pipelineTimeChange?.metadata["relative_change"] ?? "0") ?? 0
    #expect(relativeChange == 20.0, "Relative change should be approximately 20%")
  }

  // MARK: - Configuration Tests

  @Test("Relaxed configuration allows smaller changes")
  mutating func relaxedConfigurationAllowsSmallerChanges() async throws {
    try await setUp()
    // Given: Relaxed validator configuration
    let relaxedValidator = PipelineParityValidator(config: .relaxed)

    // And: Small changes that would fail with strict config
    currentOutput = createCurrentOutput()
    let slightlySlowerPipelineTime = baselineMetrics.pipelineTime * 1.15 // 15% slower (within 20% tolerance)

    currentOutput = CurrentOutput(outputStructure: currentOutput.outputStructure,
                                  fieldCount: currentOutput.fieldCount,
                                  totalRecords: currentOutput.totalRecords,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: currentOutput.fieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: slightlySlowerPipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: currentOutput.schema,
                                  schemaHash: currentOutput.schemaHash,
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity with relaxed config
    let result = try await relaxedValidator.validateParity(baseline: baselineMetrics,
                                                           current: currentOutput,
                                                           sample: goldenSample)

    // Then: Parity should pass with relaxed config
    #expect(result.isParity == true, "Parity should pass with relaxed config for small changes")
  }

  // MARK: - Edge Case Tests

  @Test("NaN/Inf values trigger automatic critical in range validation")
  mutating func naNInfValuesTriggerAutomaticCriticalInRangeValidation() async throws {
    try await setUp()
    // Given: Current output with NaN values in cross_k
    currentOutput = createCurrentOutput()
    let nanFieldRanges: [String: ValueRange] = [
      "cross_k": ValueRange(min: Double.nan, max: 100, mean: 45.2, description: "NaN cross_k range"),
      "cross_n": ValueRange(min: 1, max: 200, mean: 98.7, description: "Current cross_n range"),
      "via_penalty_sec": ValueRange(min: 0, max: 300, mean: 45.8, description: "Current penalty range"),
      "gate_anom": ValueRange(min: 0, max: 1, mean: 0.5, description: "Current anomaly range"),
      "alternates_total": ValueRange(min: 1, max: 5, mean: 3.2, description: "Current alternates range"),
    ]

    currentOutput = CurrentOutput(outputStructure: currentOutput.outputStructure,
                                  fieldCount: currentOutput.fieldCount,
                                  totalRecords: currentOutput.totalRecords,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: nanFieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: currentOutput.pipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: currentOutput.schema,
                                  schemaHash: currentOutput.schemaHash,
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Parity should fail with critical NaN detection
    #expect(result.isParity == false, "Parity should fail when NaN values are detected")

    let rangeChanges = result.detectedChanges.filter { $0.changeType == .range }
    let nanChange = rangeChanges.first { $0.affectedField == "cross_k" }
    #expect(nanChange != nil, "NaN change should be detected")
    #expect(nanChange?.severity == .critical, "NaN detection should be critical")
    #expect(nanChange?.metadata["baseline_has_nan_inf"] == "false")
    #expect(nanChange?.metadata["current_has_nan_inf"] == "true")
  }

  @Test("Zero baseline and current define relative delta as zero")
  mutating func zeroBaselineAndCurrentDefineRelativeDeltaAsZero() async throws {
    try await setUp()
    // Given: Current output with zero values that could cause division by zero
    currentOutput = createCurrentOutput()
    let zeroFieldRanges: [String: ValueRange] = [
      "cross_k": ValueRange(min: 0, max: 0, mean: 0, description: "Zero cross_k range"),
      "cross_n": ValueRange(min: 0, max: 0, mean: 0, description: "Zero cross_n range"),
      "via_penalty_sec": ValueRange(min: 0, max: 300, mean: 45.8, description: "Current penalty range"),
      "gate_anom": ValueRange(min: 0, max: 1, mean: 0.5, description: "Current anomaly range"),
      "alternates_total": ValueRange(min: 1, max: 5, mean: 3.2, description: "Current alternates range"),
    ]

    currentOutput = CurrentOutput(outputStructure: currentOutput.outputStructure,
                                  fieldCount: currentOutput.fieldCount,
                                  totalRecords: currentOutput.totalRecords,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: zeroFieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: currentOutput.pipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: currentOutput.schema,
                                  schemaHash: currentOutput.schemaHash,
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Validation should complete without division by zero errors
    #expect(result.isParity == false, "Parity should fail due to range differences")

    // Check that no crashes occurred during validation
    let rangeChanges = result.detectedChanges.filter { $0.changeType == .range }
    #expect(rangeChanges.isEmpty == false, "Range changes should be detected")
  }

  // MARK: - Module Impact Analysis Tests

  @Test("Module impact analysis identifies correct module")
  mutating func moduleImpactAnalysisIdentifiesCorrectModule() async throws {
    try await setUp()
    // Given: Current output with shape change
    currentOutput = createCurrentOutput()
    currentOutput = CurrentOutput(outputStructure: "Modified NDJSON",
                                  fieldCount: 12,
                                  totalRecords: currentOutput.totalRecords,
                                  bridgeRecordCounts: currentOutput.bridgeRecordCounts,
                                  timeDistribution: currentOutput.timeDistribution,
                                  fieldRanges: currentOutput.fieldRanges,
                                  fieldDistributions: currentOutput.fieldDistributions,
                                  pipelineTime: currentOutput.pipelineTime,
                                  peakMemory: currentOutput.peakMemory,
                                  schema: currentOutput.schema,
                                  schemaHash: currentOutput.schemaHash,
                                  stageTimings: currentOutput.stageTimings,
                                  memoryMetrics: currentOutput.memoryMetrics)

    // When: Validating parity
    let result = try await validator.validateParity(baseline: baselineMetrics,
                                                    current: currentOutput,
                                                    sample: goldenSample)

    // Then: Module impact analysis should identify BridgeDataProcessor
    #expect(result.isParity == false, "Parity should fail")
    #expect(result.affectedModule == .bridgeDataProcessor, "BridgeDataProcessor should be identified for shape changes")
    #expect(result.likelyModules.isEmpty == false, "Ranked module list should not be empty")
    #expect(result.likelyModules.first == .bridgeDataProcessor, "BridgeDataProcessor should be first in ranked list")
  }

  // MARK: - Parity Gate Facade Tests

  @Test("Parity gate facade runs validation")
  mutating func parityGateFacadeRunsValidation() async throws {
    try await setUp()
    // Given: Baseline metrics that can be serialized
    let baselineData = try JSONEncoder.bridgeEncoder().encode(baselineMetrics)
    let baselineURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_baseline.json")
    try baselineData.write(to: baselineURL)

    defer {
      try? FileManager.default.removeItem(at: baselineURL)
    }

    // And: Current output
    currentOutput = createCurrentOutput()

    // When: Running parity gate
    let result = try await ParityGate.run(baselineURL: baselineURL,
                                          current: currentOutput,
                                          sample: goldenSample)

    // Then: Validation should complete successfully
    #expect(result.isParity == true, "Parity should pass for identical outputs")
  }
}
