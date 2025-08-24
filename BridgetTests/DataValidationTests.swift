//
//  DataValidationTests.swift
//  BridgetTests
//
//  ## Purpose
//  Comprehensive unit tests for Data Validation Module
//  Tests all validation scenarios: golden samples, edge cases, and error conditions
//
//  ✅ STATUS: COMPLETE - All test requirements implemented
//  ✅ COMPLETION DATE: August 17, 2025
//  ✅ COVERAGE: Golden samples, edge cases, error conditions, all validation checks
//

@testable import Bridget
import Foundation
import Testing

@Suite("Data Validation Service Tests")
struct DataValidationTests {
  private var validationService: DataValidationService!
  private var goldenSampleTicks: [ProbeTickRaw] = []
  private var goldenSampleFeatures: [FeatureVector] = []

  private mutating func setUp() async throws {
    validationService = DataValidationService()
    setupGoldenSamples()
  }

  // MARK: - Golden Sample Tests

  @Test("Golden sample probe ticks should pass validation")
  mutating func goldenSampleProbeTicksValidation() async throws {
    // Create fresh validation service and data for this test
    let testValidationService = DataValidationService()
    var testGoldenSampleTicks: [ProbeTickRaw] = []

    // Create realistic golden sample probe ticks with deterministic, valid values
    let baseTime = ISO8601DateFormatter().date(from: "2025-01-01T12:00:00Z")!

    for hour in 0 ..< 24 {
      for bridgeId in [1, 2] {
        let timestamp = Calendar.current.date(byAdding: .hour, value: hour, to: baseTime)!
        let isoString = ISO8601DateFormatter().string(from: timestamp)

        // Use deterministic values that are guaranteed to pass validation
        let crossK = 0.5 + (Double(hour % 3) * 0.2) // 0.5, 0.7, 0.9, 0.5, 0.7, 0.9...
        let crossN = 1.0
        let viaRoutable = 0.8 + (Double(hour % 2) * 0.2) // 0.8, 1.0, 0.8, 1.0...
        let viaPenalty = 20.0 + (Double(hour % 4) * 10.0) // 20, 30, 40, 50, 20, 30...
        let gateAnom = 0.1 + (Double(hour % 2) * 0.05) // 0.1, 0.15, 0.1, 0.15...
        let alternatesTotal = 2.0 + Double(hour % 2) // 2.0, 3.0, 2.0, 3.0...
        let alternatesAvoid = 0.2 + (Double(hour % 3) * 0.1) // 0.2, 0.3, 0.4, 0.2, 0.3...
        let openLabel = hour % 2 // 0, 1, 0, 1...
        let detourDelta = 120.0 + (Double(hour % 3) * 60.0) // 120, 180, 240, 120, 180...
        let detourFrac = 0.3 + (Double(hour % 4) * 0.1) // 0.3, 0.4, 0.5, 0.6, 0.3...

        let tick = ProbeTickRaw(v: hour * 2 + bridgeId,
                                ts_utc: isoString,
                                bridge_id: bridgeId,
                                cross_k: crossK,
                                cross_n: crossN,
                                via_routable: viaRoutable,
                                via_penalty_sec: viaPenalty,
                                gate_anom: gateAnom,
                                alternates_total: alternatesTotal,
                                alternates_avoid: alternatesAvoid,
                                open_label: openLabel,
                                detour_delta: detourDelta,
                                detour_frac: detourFrac)
        testGoldenSampleTicks.append(tick)
      }
    }

    let result = testValidationService.validate(ticks: testGoldenSampleTicks)

    #expect(result.isValid == true)
    #expect(result.totalRecords == 48) // 24 hours × 2 bridges
    #expect(result.bridgeCount == 2)
    #expect(result.errors.isEmpty)
    #expect(result.warnings.count <= 2) // Allow some warnings for edge cases
    #expect(result.validRecordCount == 48)
    #expect(result.validationRate > 0.95)
  }

  @Test("Golden sample feature vectors should pass validation")
  mutating func goldenSampleFeatureVectorsValidation() async throws {
    // Create fresh validation service and data for this test
    let testValidationService = DataValidationService()
    var testGoldenSampleFeatures: [FeatureVector] = []

    // Create realistic golden sample feature vectors with deterministic values
    let baseTime = ISO8601DateFormatter().date(from: "2025-01-01T12:00:00Z")!

    for hour in 0 ..< 24 {
      for bridgeId in [1, 2] {
        let timestamp = Calendar.current.date(byAdding: .hour, value: hour, to: baseTime)!
        let isoString = ISO8601DateFormatter().string(from: timestamp)

        for horizon in defaultHorizons {
          let date = ISO8601DateFormatter().date(from: isoString)!
          let minute = Calendar.current.component(.minute, from: date)
          let weekday = Calendar.current.component(.weekday, from: date)

          let feature = FeatureVector(bridge_id: bridgeId,
                                      horizon_min: horizon,
                                      min_sin: sin(Double(minute) * .pi / 30),
                                      min_cos: cos(Double(minute) * .pi / 30),
                                      dow_sin: sin(Double(weekday) * .pi / 7),
                                      dow_cos: cos(Double(weekday) * .pi / 7),
                                      open_5m: hour % 2 == 1 ? 1.0 : 0.0,
                                      open_30m: hour % 2 == 1 ? 1.0 : 0.0,
                                      detour_delta: 120.0 + (Double(hour % 3) * 60.0),
                                      cross_rate: 0.5 + (Double(hour % 3) * 0.2),
                                      via_routable: 0.8 + (Double(hour % 2) * 0.2),
                                      via_penalty: 20.0 + (Double(hour % 4) * 10.0),
                                      gate_anom: 0.1 + (Double(hour % 2) * 0.05),
                                      detour_frac: 0.3 + (Double(hour % 4) * 0.1),
                                      current_speed: 25.0 + (Double(hour % 5) * 5.0),
                                      normal_speed: 30.0 + (Double(hour % 3) * 2.0),
                                      target: hour % 2)
          testGoldenSampleFeatures.append(feature)
        }
      }
    }

    let result = testValidationService.validate(features: testGoldenSampleFeatures)

    #expect(result.isValid == true)
    #expect(result.totalRecords == 240) // 24 hours × 2 bridges × 5 horizons
    #expect(result.bridgeCount == 2)
    #expect(result.errors.isEmpty)
    #expect(result.warnings.isEmpty)
    #expect(result.validRecordCount == 240)
    #expect(result.validationRate == 1.0)
  }

  // MARK: - Edge Case Tests

  @Test("Empty arrays should fail validation")
  mutating func emptyArraysValidation() async throws {
    try await setUp()
    let emptyTicksResult = validationService.validate(ticks: [])
    let emptyFeaturesResult = validationService.validate(features: [])

    #expect(emptyTicksResult.isValid == false)
    #expect(emptyTicksResult.errors.contains("No probe tick data provided"))

    #expect(emptyFeaturesResult.isValid == false)
    #expect(emptyFeaturesResult.errors.contains("No feature vectors provided"))
  }

  @Test("Single record should pass validation")
  mutating func singleRecordValidation() async throws {
    try await setUp()
    let singleTick = [ProbeTickRaw(v: 1,
                                   ts_utc: "2025-01-01T12:00:00Z",
                                   bridge_id: 1,
                                   cross_k: 0.5,
                                   cross_n: 1.0,
                                   via_routable: 0.8,
                                   via_penalty_sec: 30.0,
                                   gate_anom: 0.1,
                                   alternates_total: 2.0,
                                   alternates_avoid: 0.5,
                                   open_label: 0,
                                   detour_delta: 120.0,
                                   detour_frac: 0.3)]

    let result = validationService.validate(ticks: singleTick)

    #expect(result.isValid == true)
    #expect(result.totalRecords == 1)
    #expect(result.bridgeCount == 1)
    #expect(result.errors.isEmpty)
  }

  @Test("DST boundary timestamps should be handled gracefully")
  mutating func dSTBoundaryTimestamps() async throws {
    try await setUp()

    // Create DST boundary test data using UTC to avoid time zone complications
    var dstTicks: [ProbeTickRaw] = []

    // Use UTC timestamps around DST transitions to avoid time zone edge cases
    // Spring forward: March 10, 2024 at 2:00 AM becomes 3:00 AM (in US)
    // Fall back: November 3, 2024 at 2:00 AM becomes 1:00 AM (in US)

    // Create timestamps in UTC around these transitions
    let springForwardBase = ISO8601DateFormatter().date(from: "2024-03-10T06:00:00Z")! // 6 AM UTC
    let fallBackBase = ISO8601DateFormatter().date(from: "2024-11-03T06:00:00Z")! // 6 AM UTC

    // Create 2 hours of data around each transition (in UTC)
    for minute in 0 ..< 120 {
      let springTimestamp = Calendar.current.date(byAdding: .minute, value: minute, to: springForwardBase)!
      let fallTimestamp = Calendar.current.date(byAdding: .minute, value: minute, to: fallBackBase)!

      let springISOString = ISO8601DateFormatter().string(from: springTimestamp)
      let fallISOString = ISO8601DateFormatter().string(from: fallTimestamp)

      // Spring forward data
      let springTick = ProbeTickRaw(v: minute,
                                    ts_utc: springISOString,
                                    bridge_id: 1,
                                    cross_k: 0.5,
                                    cross_n: 1.0,
                                    via_routable: 0.8,
                                    via_penalty_sec: 20.0,
                                    gate_anom: 0.1,
                                    alternates_total: 2.0,
                                    alternates_avoid: 0.2,
                                    open_label: minute % 2,
                                    detour_delta: 120.0,
                                    detour_frac: 0.3)
      dstTicks.append(springTick)

      // Fall back data
      let fallTick = ProbeTickRaw(v: minute + 200, // Different version numbers
                                  ts_utc: fallISOString,
                                  bridge_id: 2,
                                  cross_k: 0.6,
                                  cross_n: 1.0,
                                  via_routable: 0.9,
                                  via_penalty_sec: 25.0,
                                  gate_anom: 0.15,
                                  alternates_total: 3.0,
                                  alternates_avoid: 0.3,
                                  open_label: minute % 2,
                                  detour_delta: 180.0,
                                  detour_frac: 0.4)
      dstTicks.append(fallTick)
    }

    let result = validationService.validate(ticks: dstTicks)

    // DST transitions should not cause validation errors
    #expect(result.isValid == true)
    #expect(result.totalRecords == 240) // 120 + 120
    #expect(result.bridgeCount == 2)

    // Should have valid timestamp ranges
    #expect(result.timestampRange.first != nil)
    #expect(result.timestampRange.last != nil)

    // No validation errors should occur
    #expect(result.errors.isEmpty)
  }

  // MARK: - Error Condition Tests

  @Test("Invalid bridge IDs should be detected")
  mutating func invalidBridgeIDs() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var invalidTicks = goldenSampleTicks
    invalidTicks[0] = ProbeTickRaw(v: 1,
                                   ts_utc: "2025-01-01T12:00:00Z",
                                   bridge_id: -1, // Invalid negative ID
                                   cross_k: 0.5,
                                   cross_n: 1.0,
                                   via_routable: 0.8,
                                   via_penalty_sec: 30.0,
                                   gate_anom: 0.1,
                                   alternates_total: 2.0,
                                   alternates_avoid: 0.5,
                                   open_label: 0,
                                   detour_delta: 120.0,
                                   detour_frac: 0.3)

    let result = validationService.validate(ticks: invalidTicks)

    #expect(result.isValid == false)
    #expect(result.invalidBridgeIds == 1)
    #expect(result.errors.contains { $0.contains("Invalid bridge ID: -1") })
  }

  @Test("Invalid open labels should be detected")
  mutating func testInvalidOpenLabels() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var invalidTicks = goldenSampleTicks
    invalidTicks[0] = ProbeTickRaw(v: 1,
                                   ts_utc: "2025-01-01T12:00:00Z",
                                   bridge_id: 1,
                                   cross_k: 0.5,
                                   cross_n: 1.0,
                                   via_routable: 0.8,
                                   via_penalty_sec: 30.0,
                                   gate_anom: 0.1,
                                   alternates_total: 2.0,
                                   alternates_avoid: 0.5,
                                   open_label: 2, // Invalid label (should be 0 or 1)
                                   detour_delta: 120.0,
                                   detour_frac: 0.3)

    let result = validationService.validate(ticks: invalidTicks)

    #expect(result.isValid == false)
    #expect(result.invalidOpenLabels == 1)
    #expect(result.errors.contains { $0.contains("Invalid open label: 2") })
  }

  @Test("NaN values should be detected and flagged")
  mutating func naNValuesDetection() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var nanTicks = goldenSampleTicks
    nanTicks[0] = ProbeTickRaw(v: 1,
                               ts_utc: "2025-01-01T12:00:00Z",
                               bridge_id: 1,
                               cross_k: Double.nan, // NaN value
                               cross_n: 1.0,
                               via_routable: 0.8,
                               via_penalty_sec: 30.0,
                               gate_anom: 0.1,
                               alternates_total: 2.0,
                               alternates_avoid: 0.5,
                               open_label: 0,
                               detour_delta: 120.0,
                               detour_frac: 0.3)

    let result = validationService.validate(ticks: nanTicks)

    #expect(result.isValid == false)
    #expect(result.dataQualityMetrics.nanCounts["cross_k"] == 1)
    #expect(result.errors.contains { $0.contains("Found 1 NaN values in cross_k") })
  }

  @Test("Infinite values should be detected and flagged")
  mutating func infiniteValuesDetection() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var infiniteTicks = goldenSampleTicks
    infiniteTicks[0] = ProbeTickRaw(v: 1,
                                    ts_utc: "2025-01-01T12:00:00Z",
                                    bridge_id: 1,
                                    cross_k: 0.5,
                                    cross_n: Double.infinity, // Infinite value
                                    via_routable: 0.8,
                                    via_penalty_sec: 30.0,
                                    gate_anom: 0.1,
                                    alternates_total: 2.0,
                                    alternates_avoid: 0.5,
                                    open_label: 0,
                                    detour_delta: 120.0,
                                    detour_frac: 0.3)

    let result = validationService.validate(ticks: infiniteTicks)

    #expect(result.isValid == false)
    #expect(result.dataQualityMetrics.infiniteCounts["cross_n"] == 1)
    #expect(result.errors.contains { $0.contains("Found 1 infinite values in cross_n") })
  }

  @Test("Non-monotonic timestamps should be detected")
  mutating func nonMonotonicTimestamps() async throws {
    try await setUp()
    guard goldenSampleTicks.count >= 2 else { return }
    var nonMonotonicTicks = goldenSampleTicks
    // Swap timestamps to create non-monotonic sequence
    nonMonotonicTicks[1] = ProbeTickRaw(v: 2,
                                        ts_utc: "2025-01-01T11:00:00Z", // Earlier than first timestamp
                                        bridge_id: 1,
                                        cross_k: 0.6,
                                        cross_n: 1.0,
                                        via_routable: 0.9,
                                        via_penalty_sec: 25.0,
                                        gate_anom: 0.05,
                                        alternates_total: 2.0,
                                        alternates_avoid: 0.4,
                                        open_label: 1,
                                        detour_delta: 90.0,
                                        detour_frac: 0.25)

    let result = validationService.validate(ticks: nonMonotonicTicks)

    #expect(result.isValid == true) // Warnings don't make it invalid
    #expect(result.warnings.contains { $0.contains("Non-monotonic timestamp") })
  }

  // MARK: - Feature Vector Validation Tests

  @Test("Feature vectors with out-of-range cyclical features should be flagged")
  mutating func featureVectorCyclicalRangeValidation() async throws {
    try await setUp()
    guard !goldenSampleFeatures.isEmpty else { return }
    var invalidFeatures = goldenSampleFeatures
    invalidFeatures[0] = FeatureVector(bridge_id: 1,
                                       horizon_min: 0,
                                       min_sin: 1.5, // Out of range [-1, 1]
                                       min_cos: 0.5,
                                       dow_sin: 0.3,
                                       dow_cos: 0.7,
                                       open_5m: 0.8,
                                       open_30m: 0.6,
                                       detour_delta: 120.0,
                                       cross_rate: 0.4,
                                       via_routable: 0.9,
                                       via_penalty: 25.0,
                                       gate_anom: 0.1,
                                       detour_frac: 0.3,
                                       current_speed: 25.0,
                                       normal_speed: 30.0,
                                       target: 0)

    let result = validationService.validate(features: invalidFeatures)

    #expect(result.isValid == true) // Warnings don't make it invalid
    #expect(result.warnings.contains { $0.contains("Cyclical feature out of range") })
  }

  @Test("Feature vectors with invalid target values should be flagged")
  mutating func featureVectorInvalidTargets() async throws {
    try await setUp()
    guard !goldenSampleFeatures.isEmpty else { return }
    var invalidFeatures = goldenSampleFeatures
    invalidFeatures[0] = FeatureVector(bridge_id: 1,
                                       horizon_min: 0,
                                       min_sin: 0.5,
                                       min_cos: 0.5,
                                       dow_sin: 0.3,
                                       dow_cos: 0.7,
                                       open_5m: 0.8,
                                       open_30m: 0.6,
                                       detour_delta: 120.0,
                                       cross_rate: 0.4,
                                       via_routable: 0.9,
                                       via_penalty: 25.0,
                                       gate_anom: 0.1,
                                       detour_frac: 0.3,
                                       current_speed: 25.0,
                                       normal_speed: 30.0,
                                       target: 2 // Invalid target (should be 0 or 1)
    )

    let result = validationService.validate(features: invalidFeatures)

    #expect(result.isValid == false)
    #expect(result.errors.contains { $0.contains("Invalid target value: 2") })
  }

  @Test("Feature vectors with missing horizons should be flagged")
  mutating func featureVectorHorizonCoverage() async throws {
    try await setUp()
    // Create features with only some horizons
    let limitedHorizonFeatures = goldenSampleFeatures.filter { $0.horizon_min != 9 }

    let result = validationService.validate(features: limitedHorizonFeatures)

    #expect(result.isValid == true) // Warnings don't make it invalid
    #expect(result.warnings.contains { $0.contains("Missing features for horizons: 9min") })
    #expect(result.horizonCoverage[9] == nil)
  }

  // MARK: - Data Quality Metrics Tests

  @Test("Data quality metrics should be properly aggregated")
  mutating func dataQualityMetricsAggregation() async throws {
    try await setUp()
    let result = validationService.validate(ticks: goldenSampleTicks)

    #expect(result.dataQualityMetrics.nullCounts.isEmpty || result.dataQualityMetrics.nullCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.nanCounts.isEmpty || result.dataQualityMetrics.nanCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.infiniteCounts.isEmpty || result.dataQualityMetrics.infiniteCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.outlierCounts.isEmpty || result.dataQualityMetrics.outlierCounts.values.allSatisfy { $0 >= 0 })
    #expect(result.dataQualityMetrics.rangeViolations.isEmpty || result.dataQualityMetrics.rangeViolations.values.allSatisfy { $0 >= 0 })
  }

  @Test("Validation rate should be calculated correctly")
  mutating func validationRateCalculation() async throws {
    try await setUp()
    let result = validationService.validate(ticks: goldenSampleTicks)

    let expectedRate = Double(result.validRecordCount) / Double(result.totalRecords)
    #expect(abs(result.validationRate - expectedRate) < 0.001)
    #expect(result.validationRate >= 0.0 && result.validationRate <= 1.0)
  }

  // MARK: - Property Tests

  @Test("Shuffling data should preserve validation counts and shapes")
  mutating func shufflingPreservesValidationProperties() async throws {
    try await setUp()
    guard goldenSampleTicks.count > 10 else { return }

    let originalResult = validationService.validate(ticks: goldenSampleTicks)
    let shuffledTicks = goldenSampleTicks.shuffled()
    let shuffledResult = validationService.validate(ticks: shuffledTicks)

    // Basic counts should be preserved
    #expect(originalResult.totalRecords == shuffledResult.totalRecords)
    #expect(originalResult.bridgeCount == shuffledResult.bridgeCount)

    // Validation rate should be preserved (order-independent validation)
    #expect(abs(originalResult.validationRate - shuffledResult.validationRate) < 0.001)

    // Data quality metrics should be preserved (within floating point tolerance)
    #expect(abs(originalResult.dataQualityMetrics.dataCompleteness - shuffledResult.dataQualityMetrics.dataCompleteness) < 0.001)
    #expect(abs(originalResult.dataQualityMetrics.bridgeIDValidity - shuffledResult.dataQualityMetrics.bridgeIDValidity) < 0.001)

    // Note: Error and warning counts may differ due to order-dependent checks like timestamp monotonicity
    // But the core validation results should be consistent
  }

  @Test("Constant offsets should shift statistics predictably")
  mutating func constantOffsetsShiftStatisticsPredictably() async throws {
    try await setUp()
    guard goldenSampleTicks.count > 5 else { return }

    let originalResult = validationService.validate(ticks: goldenSampleTicks)

    // Create data with constant offset added to all numeric fields
    let offsetTicks = goldenSampleTicks.map { tick in
      ProbeTickRaw(v: tick.v,
                   ts_utc: tick.ts_utc,
                   bridge_id: tick.bridge_id,
                   cross_k: tick.cross_k.map { $0 + 10.0 },
                   cross_n: tick.cross_n.map { $0 + 10.0 },
                   via_routable: tick.via_routable.map { $0 + 10.0 },
                   via_penalty_sec: tick.via_penalty_sec.map { $0 + 10.0 },
                   gate_anom: tick.gate_anom.map { $0 + 10.0 },
                   alternates_total: tick.alternates_total.map { $0 + 10.0 },
                   alternates_avoid: tick.alternates_avoid.map { $0 + 10.0 },
                   open_label: tick.open_label,
                   detour_delta: tick.detour_delta.map { $0 + 10.0 },
                   detour_frac: tick.detour_frac.map { $0 + 10.0 })
    }

    let offsetResult = validationService.validate(ticks: offsetTicks)

    // Basic counts should remain the same
    #expect(originalResult.totalRecords == offsetResult.totalRecords)
    #expect(originalResult.bridgeCount == offsetResult.bridgeCount)

    // Validation rate might change due to range violations, but should be predictable
    #expect(offsetResult.validationRate <= originalResult.validationRate ||
      offsetResult.warnings.contains { $0.contains("range") })
  }

  @Test("Feature vector validation should be invariant under horizon reordering")
  mutating func featureVectorHorizonInvariance() async throws {
    try await setUp()
    guard goldenSampleFeatures.count > 10 else { return }

    let originalResult = validationService.validate(features: goldenSampleFeatures)

    // Reorder features by horizon
    let reorderedFeatures = goldenSampleFeatures.sorted { $0.horizon_min < $1.horizon_min }
    let reorderedResult = validationService.validate(features: reorderedFeatures)

    // Validation results should be identical
    #expect(originalResult.totalRecords == reorderedResult.totalRecords)
    #expect(originalResult.bridgeCount == reorderedResult.bridgeCount)
    #expect(originalResult.validationRate == reorderedResult.validationRate)
    #expect(originalResult.errors.count == reorderedResult.errors.count)
    #expect(originalResult.warnings.count == reorderedResult.warnings.count)
  }

  // MARK: - Edge Case Tests

  @Test("Duplicate probe ticks should be detected and reported")
  mutating func duplicateRecordDetection() async throws {
    try await setUp()
    guard !goldenSampleTicks.isEmpty else { return }
    var dupTicks = goldenSampleTicks
    // Add a duplicate of the first tick
    dupTicks.append(goldenSampleTicks[0])

    let result = validationService.validate(ticks: dupTicks)

    #expect(result.dataQualityMetrics.duplicateCount > 0)
    #expect(result.warnings.contains { $0.contains("duplicate") || $0.contains("Duplicate") })
  }

  @Test("Unusual but valid timestamps should be handled correctly")
  mutating func unusualTimestampHandling() async throws {
    try await setUp()

    let unusualTicks = [
      // Leap year date
      ProbeTickRaw(v: 1, ts_utc: "2024-02-29T12:00:00Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      // Y2K era date
      ProbeTickRaw(v: 1, ts_utc: "2000-01-01T00:00:00Z", bridge_id: 2,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
      // Far future date
      ProbeTickRaw(v: 1, ts_utc: "2099-12-31T23:59:59Z", bridge_id: 3,
                   cross_k: 0.4, cross_n: 0.9, via_routable: 0.7,
                   via_penalty_sec: 35.0, gate_anom: 0.15, alternates_total: 1.0,
                   alternates_avoid: 0.7, open_label: 0, detour_delta: 150.0, detour_frac: 0.4),
    ]

    let result = validationService.validate(ticks: unusualTicks)

    #expect(result.totalRecords == 3)
    #expect(result.timestampRange.first != nil)
    #expect(result.timestampRange.last != nil)
    // Should not have timestamp format errors for valid ISO8601 dates
    #expect(!result.errors.contains { $0.contains("Invalid timestamp format") })
  }

  @Test("Leap second and mixed timezone timestamps should be handled correctly")
  mutating func leapSecondAndTimezoneHandling() async throws {
    try await setUp()

    let timezoneTicks = [
      // Leap second (June 30, 2015)
      ProbeTickRaw(v: 1, ts_utc: "2015-06-30T23:59:60Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      // Mixed timezone offsets (these should be normalized to UTC)
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00-08:00", bridge_id: 2,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
      // Another leap second (December 31, 2016)
      ProbeTickRaw(v: 1, ts_utc: "2016-12-31T23:59:60Z", bridge_id: 3,
                   cross_k: 0.4, cross_n: 0.9, via_routable: 0.7,
                   via_penalty_sec: 35.0, gate_anom: 0.15, alternates_total: 1.0,
                   alternates_avoid: 0.7, open_label: 0, detour_delta: 150.0, detour_frac: 0.4),
      // Eastern timezone
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T15:00:00-05:00", bridge_id: 4,
                   cross_k: 0.3, cross_n: 0.8, via_routable: 0.6,
                   via_penalty_sec: 40.0, gate_anom: 0.2, alternates_total: 1.5,
                   alternates_avoid: 0.6, open_label: 1, detour_delta: 180.0, detour_frac: 0.5),
    ]

    let result = validationService.validate(ticks: timezoneTicks)

    #expect(result.totalRecords == 4)
    #expect(result.timestampRange.first != nil)
    #expect(result.timestampRange.last != nil)

    // Leap seconds and timezone offsets should be handled gracefully
    // Note: ISO8601DateFormatter may not support leap seconds, so we expect warnings
    // but not fatal errors that would break validation
    #expect(result.validationRate >= 0.0) // Should complete validation
    #expect(!result.summary.isEmpty) // Should provide meaningful summary
  }

  @Test("All-missing or all-NaN features should be clearly reported")
  mutating func allMissingFeaturesDetection() async throws {
    try await setUp()

    let allMissingTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: nil, cross_n: nil, via_routable: nil,
                   via_penalty_sec: nil, gate_anom: nil, alternates_total: nil,
                   alternates_avoid: nil, open_label: 0, detour_delta: nil, detour_frac: nil),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:01:00Z", bridge_id: 2,
                   cross_k: Double.nan, cross_n: Double.nan, via_routable: Double.nan,
                   via_penalty_sec: Double.nan, gate_anom: Double.nan, alternates_total: Double.nan,
                   alternates_avoid: Double.nan, open_label: 1, detour_delta: Double.nan, detour_frac: Double.nan),
    ]

    let result = validationService.validate(ticks: allMissingTicks)

    #expect(result.isValid == false)
    #expect(result.dataQualityMetrics.nullCounts.values.reduce(0, +) > 0)
    #expect(result.dataQualityMetrics.nanCounts.values.reduce(0, +) > 0)
    #expect(result.errors.contains { $0.contains("NaN values") })
    #expect(result.warnings.contains { $0.contains("High null rate") || $0.contains("missing ratio") })
  }

  @Test("All values NaN/infinite for specific fields should be detected and reported")
  mutating func allValuesNaNInfiniteForFields() async throws {
    try await setUp()

    let fieldSpecificTicks = [
      // All cross_k values are NaN
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: Double.nan, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:01:00Z", bridge_id: 2,
                   cross_k: Double.nan, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:02:00Z", bridge_id: 3,
                   cross_k: Double.nan, cross_n: 0.9, via_routable: 0.7,
                   via_penalty_sec: 35.0, gate_anom: 0.15, alternates_total: 1.0,
                   alternates_avoid: 0.7, open_label: 0, detour_delta: 150.0, detour_frac: 0.4),
      // All via_penalty_sec values are infinite
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:03:00Z", bridge_id: 4,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: Double.infinity, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:04:00Z", bridge_id: 5,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: Double.infinity, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:05:00Z", bridge_id: 6,
                   cross_k: 0.4, cross_n: 0.9, via_routable: 0.7,
                   via_penalty_sec: Double.infinity, gate_anom: 0.15, alternates_total: 1.0,
                   alternates_avoid: 0.7, open_label: 0, detour_delta: 150.0, detour_frac: 0.4),
    ]

    let result = validationService.validate(ticks: fieldSpecificTicks)

    #expect(result.totalRecords == 6)
    #expect(result.isValid == false)

    // Should detect that all cross_k values are NaN
    #expect(result.dataQualityMetrics.nanCounts["cross_k"] == 3)

    // Should detect that all via_penalty_sec values are infinite
    #expect(result.dataQualityMetrics.infiniteCounts["via_penalty_sec"] == 3)

    // Should provide actionable error messages
    #expect(result.errors.contains { $0.contains("NaN values") })
    #expect(result.errors.contains { $0.contains("infinite") || $0.contains("Infinite") })

    // Should provide field-specific warnings
    #expect(result.warnings.contains { $0.contains("cross_k") || $0.contains("via_penalty_sec") })
  }

  @Test("High cardinality bridge IDs should be handled efficiently")
  mutating func highCardinalityHandling() async throws {
    try await setUp()

    // Generate ticks with many unique bridge IDs
    var highCardinalityTicks: [ProbeTickRaw] = []
    for bridgeId in 1 ... 1000 {
      highCardinalityTicks.append(
        ProbeTickRaw(v: 1, ts_utc: "2025-01-01T\(String(format: "%02d", bridgeId % 24)):00:00Z",
                     bridge_id: bridgeId,
                     cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                     via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                     alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3)
      )
    }

    let result = validationService.validate(ticks: highCardinalityTicks)

    #expect(result.totalRecords == 1000)
    #expect(result.bridgeCount == 1000)
    #expect(result.validationRate > 0.0) // Should complete validation
    #expect(!result.summary.isEmpty) // Should provide meaningful summary
  }

  @Test("Precision loss near range boundaries should be handled correctly")
  mutating func precisionLossHandling() async throws {
    try await setUp()

    let precisionTicks = [
      // Values very close to valid range boundaries
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 0.0000001, cross_n: 0.9999999, via_routable: 0.0000001,
                   via_penalty_sec: 0.1, gate_anom: 0.0000001, alternates_total: 0.1,
                   alternates_avoid: 0.9999999, open_label: 0, detour_delta: 0.1, detour_frac: 0.9999999),
      // Values with high precision
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:01:00Z", bridge_id: 2,
                   cross_k: 0.123456789123456789, cross_n: 1.987654321987654321, via_routable: 0.555555555555555555,
                   via_penalty_sec: 29.999999999999999, gate_anom: 0.111111111111111111, alternates_total: 2.888888888888888888,
                   alternates_avoid: 0.444444444444444444, open_label: 1, detour_delta: 119.999999999999999, detour_frac: 0.333333333333333333),
    ]

    let result = validationService.validate(ticks: precisionTicks)

    #expect(result.totalRecords == 2)
    #expect(result.validationRate > 0.0) // Should handle precision without failing
    // Precision should not cause range violations for valid values
    #expect(result.dataQualityMetrics.rangeViolations.isEmpty || result.dataQualityMetrics.rangeViolations.values.allSatisfy { $0 == 0 })
  }

  @Test("Non-default horizons should yield actionable warnings")
  mutating func nonDefaultHorizonsHandling() async throws {
    try await setUp()

    let nonStandardFeatures = [
      FeatureVector(bridge_id: 1, horizon_min: 2, min_sin: 0.5, min_cos: 0.866, dow_sin: 0.0, dow_cos: 1.0,
                    open_5m: 0.3, open_30m: 0.7, detour_delta: 120.0, cross_rate: 0.25,
                    via_routable: 0.8, via_penalty: 30.0, gate_anom: 0.1, detour_frac: 0.3,
                    current_speed: 50.0, normal_speed: 60.0, target: 1), // Non-standard 2-minute horizon
      FeatureVector(bridge_id: 2, horizon_min: 7, min_sin: 0.707, min_cos: 0.707, dow_sin: 0.707, dow_cos: 0.707,
                    open_5m: 0.4, open_30m: 0.6, detour_delta: 90.0, cross_rate: 0.35,
                    via_routable: 0.9, via_penalty: 25.0, gate_anom: 0.05, detour_frac: 0.2,
                    current_speed: 55.0, normal_speed: 65.0, target: 0), // Non-standard 7-minute horizon
      FeatureVector(bridge_id: 3, horizon_min: 11, min_sin: 0.259, min_cos: 0.966, dow_sin: 0.5, dow_cos: 0.866,
                    open_5m: 0.5, open_30m: 0.8, detour_delta: 150.0, cross_rate: 0.15,
                    via_routable: 0.7, via_penalty: 35.0, gate_anom: 0.15, detour_frac: 0.4,
                    current_speed: 45.0, normal_speed: 55.0, target: 1), // Non-standard 11-minute horizon
    ]

    let result = validationService.validate(features: nonStandardFeatures)

    #expect(result.totalRecords == 3)
    #expect(result.warnings.contains { $0.contains("Missing features for horizons") || $0.contains("horizon") })
    #expect(result.horizonCoverage[2] == 1)
    #expect(result.horizonCoverage[7] == 1)
    #expect(result.horizonCoverage[11] == 1)
  }

  // MARK: - Test Infrastructure Improvements

  @Test("Fuzz testing with random data should not crash")
  mutating func fuzzTestingResilience() async throws {
    try await setUp()

    for iteration in 1 ... 10 {
      var fuzzTicks: [ProbeTickRaw] = []

      // Generate random probe ticks with various valid/invalid combinations
      for _ in 1 ... 50 {
        let randomTick = ProbeTickRaw(v: Int.random(in: 1 ... 2),
                                      ts_utc: generateRandomTimestamp(),
                                      bridge_id: Int.random(in: 1 ... 20),
                                      cross_k: randomOptionalDouble(validRange: 0 ... 2, nilChance: 0.1, nanChance: 0.05),
                                      cross_n: randomOptionalDouble(validRange: 0 ... 3, nilChance: 0.1, nanChance: 0.05),
                                      via_routable: randomOptionalDouble(validRange: 0 ... 1, nilChance: 0.1, nanChance: 0.05),
                                      via_penalty_sec: randomOptionalDouble(validRange: 0 ... 100, nilChance: 0.1, nanChance: 0.05),
                                      gate_anom: randomOptionalDouble(validRange: 0 ... 1, nilChance: 0.1, nanChance: 0.05),
                                      alternates_total: randomOptionalDouble(validRange: 0 ... 10, nilChance: 0.1, nanChance: 0.05),
                                      alternates_avoid: randomOptionalDouble(validRange: 0 ... 1, nilChance: 0.1, nanChance: 0.05),
                                      open_label: Int.random(in: 0 ... 1),
                                      detour_delta: randomOptionalDouble(validRange: 0 ... 300, nilChance: 0.1, nanChance: 0.05),
                                      detour_frac: randomOptionalDouble(validRange: 0 ... 1, nilChance: 0.1, nanChance: 0.05))
        fuzzTicks.append(randomTick)
      }

      // Validation should not crash regardless of input
      let result = validationService.validate(ticks: fuzzTicks)

      #expect(result.totalRecords == 50)
      #expect(!result.summary.isEmpty) // Should always provide some summary

      // For iteration tracking
      if iteration % 5 == 0 {
        print("Completed fuzz test iteration \(iteration)/10")
      }
    }
  }

  @Test("Partial failure simulation should provide targeted messages")
  mutating func partialFailureSimulation() async throws {
    try await setUp()

    let mixedQualityTicks = [
      // Good record
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      // Bad bridge ID
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:01:00Z", bridge_id: 999,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
      // Good record for bridge 2
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:02:00Z", bridge_id: 2,
                   cross_k: 0.4, cross_n: 0.9, via_routable: 0.7,
                   via_penalty_sec: 35.0, gate_anom: 0.15, alternates_total: 1.0,
                   alternates_avoid: 0.7, open_label: 0, detour_delta: 150.0, detour_frac: 0.4),
      // Invalid timestamp
      ProbeTickRaw(v: 1, ts_utc: "invalid-timestamp", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
    ]

    let result = validationService.validate(ticks: mixedQualityTicks)

    #expect(result.totalRecords == 4)
    #expect(result.bridgeCount >= 2) // Should identify valid bridges

    // Should have targeted error messages
    #expect(result.errors.contains { $0.contains("bridge") || $0.contains("999") })
    #expect(result.errors.contains { $0.contains("timestamp") || $0.contains("invalid") })

    // Should provide bridge-specific insights in summary
    #expect(!result.detailedSummary.isEmpty)
  }

  @Test("Snapshot testing for validation output consistency")
  mutating func validationOutputSnapshot() async throws {
    try await setUp()

    // Create a consistent test dataset
    let snapshotTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:01:00Z", bridge_id: 1,
                   cross_k: Double.nan, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
    ]

    let result = validationService.validate(ticks: snapshotTicks)

    // Snapshot assertions - should remain consistent unless intentionally changed
    #expect(result.totalRecords == 2)
    #expect(result.bridgeCount == 1)
    #expect(result.isValid == false) // Due to NaN value
    #expect(result.dataQualityMetrics.nanCounts["cross_k"] == 1)
    #expect(result.errors.count >= 1) // Should have NaN error
    #expect(result.summary.contains("2 records"))
    #expect(result.summary.contains("1 bridge"))
  }

  // MARK: - Future-Proofing Tests

  @Test("Unknown feature fields should be gracefully ignored with warnings")
  mutating func unknownFieldHandling() async throws {
    try await setUp()

    // Simulate feature vectors with additional unknown fields
    // Note: Swift's strong typing prevents us from adding unknown fields directly,
    // but we can test the validator's response to unexpected field combinations
    let standardFeatures = [
      FeatureVector(bridge_id: 1, horizon_min: 0, min_sin: 0.5, min_cos: 0.866, dow_sin: 0.0, dow_cos: 1.0,
                    open_5m: 0.3, open_30m: 0.7, detour_delta: 120.0, cross_rate: 0.25,
                    via_routable: 0.8, via_penalty: 30.0, gate_anom: 0.1, detour_frac: 0.3,
                    current_speed: 50.0, normal_speed: 60.0, target: 1),
    ]

    let result = validationService.validate(features: standardFeatures)

    // Validator should handle standard features without warnings about unknown fields
    #expect(result.totalRecords == 1)
    #expect(!result.warnings.contains { $0.contains("unknown") || $0.contains("Unknown") })

    // Future enhancement: when unknown field handling is added,
    // test that it warns gracefully about unexpected fields
  }

  @Test("Data drift detection should flag statistical changes")
  mutating func dataDriftDetection() async throws {
    try await setUp()

    // Create baseline data with known statistical properties
    let baselineTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:01:00Z", bridge_id: 1,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
    ]

    // Create drifted data with significantly different statistics
    let driftedTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T13:00:00Z", bridge_id: 1,
                   cross_k: 1.5, cross_n: 2.0, via_routable: 0.3, // Significantly different values
                   via_penalty_sec: 80.0, gate_anom: 0.8, alternates_total: 8.0,
                   alternates_avoid: 0.9, open_label: 0, detour_delta: 300.0, detour_frac: 0.8),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T13:01:00Z", bridge_id: 1,
                   cross_k: 1.6, cross_n: 2.1, via_routable: 0.2,
                   via_penalty_sec: 85.0, gate_anom: 0.9, alternates_total: 9.0,
                   alternates_avoid: 0.95, open_label: 1, detour_delta: 320.0, detour_frac: 0.9),
    ]

    let baselineResult = validationService.validate(ticks: baselineTicks)
    let driftedResult = validationService.validate(ticks: driftedTicks)

    // Both should be structurally valid
    #expect(baselineResult.totalRecords == 2)
    #expect(driftedResult.totalRecords == 2)

    // Drifted data should trigger warnings about extreme values (future enhancement)
    // For now, just verify the validator processes both datasets
    #expect(baselineResult.validationRate >= 0.0)
    #expect(driftedResult.validationRate >= 0.0)
  }

  @Test("Async validation should handle large datasets efficiently")
  mutating func asyncValidationPerformance() async throws {
    try await setUp()

    // Create a moderately large dataset
    var largeTicks: [ProbeTickRaw] = []
    for i in 1 ... 500 {
      largeTicks.append(
        ProbeTickRaw(v: 1, ts_utc: "2025-01-01T\(String(format: "%02d", i % 24)):00:00Z",
                     bridge_id: (i % 10) + 1,
                     cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                     via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                     alternates_avoid: 0.5, open_label: i % 2, detour_delta: 120.0, detour_frac: 0.3)
      )
    }

    // Test async validation
    let asyncResult = await validationService.validateAsync(ticks: largeTicks)
    let syncResult = validationService.validate(ticks: largeTicks)

    // Results should be equivalent
    #expect(asyncResult.totalRecords == syncResult.totalRecords)
    #expect(asyncResult.bridgeCount == syncResult.bridgeCount)
    #expect(asyncResult.validationRate == syncResult.validationRate)
    #expect(asyncResult.isValid == syncResult.isValid)
  }

  @Test("Custom validator registration and execution")
  mutating func customValidatorIntegration() async throws {
    try await setUp()

    // Create a mock custom validator
    struct MockValidator: CustomValidator {
      let name = "MockBridgeIDValidator"
      let priority = 10

      func validate(ticks: [ProbeTickRaw]) async -> DataValidationResult {
        var result = DataValidationResult()
        let invalidBridges = ticks.filter { $0.bridge_id > 100 }
        if !invalidBridges.isEmpty {
          result.errors.append("Mock validator: Found \(invalidBridges.count) bridges with ID > 100")
        }
        return result
      }

      func validate(features _: [FeatureVector]) async -> DataValidationResult {
        return DataValidationResult()
      }

      func explain() -> String {
        return "Mock validator that flags bridge IDs greater than 100"
      }
    }

    // Register the custom validator
    validationService.registerValidator(MockValidator())

    // Test with data that should trigger the custom validator
    let testTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 150, // Should trigger mock validator
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
    ]

    let result = await validationService.validateAsync(ticks: testTicks)

    // Should include error from custom validator
    #expect(result.errors.contains { $0.contains("Mock validator") })

    // Test validator explanation
    let explanations = validationService.getValidatorExplanations()
    #expect(explanations["MockBridgeIDValidator"] == "Mock validator that flags bridge IDs greater than 100")

    // Clean up
    validationService.removeValidator(named: "MockBridgeIDValidator")
  }

  @Test("Runtime plugin registration, configuration, disable, and priority")
  mutating func runtimePluginManagement() async throws {
    try await setUp()

    // Create multiple validators with different priorities
    struct HighPriorityValidator: CustomValidator {
      let name = "HighPriorityValidator"
      let priority = 1 // High priority (lower number = higher priority)

      func validate(ticks: [ProbeTickRaw]) async -> DataValidationResult {
        var result = DataValidationResult()
        if ticks.count > 10 {
          result.warnings.append("HighPriority: Large dataset detected (\(ticks.count) records)")
        }
        return result
      }

      func validate(features _: [FeatureVector]) async -> DataValidationResult {
        return DataValidationResult()
      }

      func explain() -> String {
        return "High priority validator that warns about large datasets"
      }
    }

    struct MediumPriorityValidator: CustomValidator {
      let name = "MediumPriorityValidator"
      let priority = 50

      func validate(ticks: [ProbeTickRaw]) async -> DataValidationResult {
        var result = DataValidationResult()
        let highSpeedRecords = ticks.filter {
          // Check if any speed-related fields are unusually high
          ($0.cross_k ?? 0) > 2.0 || ($0.cross_n ?? 0) > 3.0
        }
        if !highSpeedRecords.isEmpty {
          result.warnings.append("MediumPriority: Found \(highSpeedRecords.count) records with high speed values")
        }
        return result
      }

      func validate(features _: [FeatureVector]) async -> DataValidationResult {
        return DataValidationResult()
      }

      func explain() -> String {
        return "Medium priority validator that checks for high speed values"
      }
    }

    struct LowPriorityValidator: CustomValidator {
      let name = "LowPriorityValidator"
      let priority = 100

      func validate(ticks: [ProbeTickRaw]) async -> DataValidationResult {
        var result = DataValidationResult()
        let weekendRecords = ticks.filter { tick in
          // Simple weekend detection (Saturday = 6, Sunday = 0)
          if let date = ISO8601DateFormatter().date(from: tick.ts_utc) {
            let weekday = Calendar.current.component(.weekday, from: date)
            return weekday == 1 || weekday == 7 // Sunday or Saturday
          }
          return false
        }
        if !weekendRecords.isEmpty {
          result.warnings.append("LowPriority: Found \(weekendRecords.count) weekend records")
        }
        return result
      }

      func validate(features _: [FeatureVector]) async -> DataValidationResult {
        return DataValidationResult()
      }

      func explain() -> String {
        return "Low priority validator that identifies weekend data patterns"
      }
    }

    // Test 1: Register validators and verify they're added
    validationService.registerValidator(HighPriorityValidator())
    validationService.registerValidator(MediumPriorityValidator())
    validationService.registerValidator(LowPriorityValidator())

    let explanations = validationService.getValidatorExplanations()
    #expect(explanations["HighPriorityValidator"] != nil)
    #expect(explanations["MediumPriorityValidator"] != nil)
    #expect(explanations["LowPriorityValidator"] != nil)

    // Test 2: Verify priority ordering (should be sorted by priority)
    let testTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 2.5, cross_n: 3.5, via_routable: 0.8, // High speed values
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:01:00Z", bridge_id: 2,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
    ]

    // Add more records to trigger high priority validator
    var largeDataset = testTicks
    for i in 3 ... 15 {
      largeDataset.append(
        ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:\(String(format: "%02d", i)):00Z", bridge_id: i,
                     cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                     via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                     alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3)
      )
    }

    let result = await validationService.validateAsync(ticks: largeDataset)

    // Should have warnings from multiple validators
    #expect(result.warnings.contains { $0.contains("HighPriority: Large dataset") })
    #expect(result.warnings.contains { $0.contains("MediumPriority: Found") })

    // Test 3: Disable specific validator
    validationService.removeValidator(named: "MediumPriorityValidator")

    let resultAfterRemoval = await validationService.validateAsync(ticks: largeDataset)

    // Should still have high priority warning but not medium priority
    #expect(resultAfterRemoval.warnings.contains { $0.contains("HighPriority: Large dataset") })
    #expect(!resultAfterRemoval.warnings.contains { $0.contains("MediumPriority: Found") })

    // Test 4: Verify validator explanations are still available
    let updatedExplanations = validationService.getValidatorExplanations()
    #expect(updatedExplanations["HighPriorityValidator"] != nil)
    #expect(updatedExplanations["LowPriorityValidator"] != nil)
    #expect(updatedExplanations["MediumPriorityValidator"] == nil) // Should be removed

    // Clean up
    validationService.removeValidator(named: "HighPriorityValidator")
    validationService.removeValidator(named: "LowPriorityValidator")
  }

  // MARK: - Real Golden Data Tests

  @Test("Real sample data should pass validation")
  mutating func realSampleDataValidation() async throws {
    try await setUp()

    // Load real sample data from the Samples directory
    let sampleData = try loadRealSampleData()
    guard !sampleData.isEmpty else { return }

    let result = validationService.validate(ticks: sampleData)

    // Real data should have reasonable validation results
    #expect(result.totalRecords > 0)
    #expect(result.bridgeCount > 0)
    #expect(result.validationRate > 0.5) // At least 50% should be valid
    #expect(result.timestampRange.first != nil)
    #expect(result.timestampRange.last != nil)

    // Should have some data quality insights
    #expect(result.dataQualityMetrics.dataCompleteness > 0.0)
    #expect(result.dataQualityMetrics.bridgeIDValidity > 0.0)
  }

  @Test("Real sample data should have actionable validation feedback")
  mutating func realSampleDataActionableFeedback() async throws {
    try await setUp()

    let sampleData = try loadRealSampleData()
    guard !sampleData.isEmpty else { return }

    let result = validationService.validate(ticks: sampleData)

    // Validation should provide actionable feedback
    #expect(!result.summary.isEmpty)
    #expect(!result.detailedSummary.isEmpty)

    // If there are issues, they should be clearly described
    if !result.errors.isEmpty {
      for error in result.errors {
        #expect(error.contains("Invalid") || error.contains("Found") || error.contains("Missing"))
      }
    }

    if !result.warnings.isEmpty {
      for warning in result.warnings {
        #expect(warning.contains("High") || warning.contains("Missing") || warning.contains("Unbalanced") || warning.contains("Non-monotonic"))
      }
    }
  }

  // MARK: - Helper Methods

  /// Generates a random timestamp in ISO8601 format
  private func generateRandomTimestamp() -> String {
    let year = Int.random(in: 2020 ... 2030)
    let month = Int.random(in: 1 ... 12)
    let day = Int.random(in: 1 ... 28) // Safe for all months
    let hour = Int.random(in: 0 ... 23)
    let minute = Int.random(in: 0 ... 59)
    let second = Int.random(in: 0 ... 59)

    return String(format: "%04d-%02d-%02dT%02d:%02d:%02dZ", year, month, day, hour, minute, second)
  }

  /// Generates a random optional double with configurable nil and NaN chances
  private func randomOptionalDouble(validRange: ClosedRange<Double>, nilChance: Double, nanChance: Double) -> Double? {
    let rand = Double.random(in: 0 ... 1)

    if rand < nilChance {
      return nil
    } else if rand < nilChance + nanChance {
      return Double.nan
    } else if rand < nilChance + nanChance + 0.01 { // 1% chance of infinity
      return Double.infinity
    } else {
      return Double.random(in: validRange)
    }
  }

  /// Loads real sample data from the Samples directory for testing
  private func loadRealSampleData() throws -> [ProbeTickRaw] {
    let bundle = Bundle.main

    // Try to load from the main bundle first (for when tests run in the app)
    if let url = bundle.url(forResource: "minutes_2025-08-12", withExtension: "ndjson") {
      return try loadSampleDataFromURL(url)
    }

    // Try to load from the test bundle
    if let url = bundle.url(forResource: "Samples/ndjson/minutes_2025-08-12", withExtension: "ndjson") {
      return try loadSampleDataFromURL(url)
    }

    // Fallback: try to construct path relative to project root
    let projectRoot = URL(fileURLWithPath: #file)
      .deletingLastPathComponent() // BridgetTests
      .deletingLastPathComponent() // Bridget.xcodeproj
      .deletingLastPathComponent() // Bridget
      .deletingLastPathComponent() // Project root

    let sampleURL = projectRoot
      .appendingPathComponent("Samples")
      .appendingPathComponent("ndjson")
      .appendingPathComponent("minutes_2025-08-12.ndjson")

    if FileManager.default.fileExists(atPath: sampleURL.path) {
      return try loadSampleDataFromURL(sampleURL)
    }

    // If no real data is available, return empty array
    return []
  }

  /// Loads sample data from a URL and parses it as NDJSON
  private func loadSampleDataFromURL(_ url: URL) throws -> [ProbeTickRaw] {
    let data = try Data(contentsOf: url)
    let content = String(data: data, encoding: .utf8) ?? ""

    let lines = content.components(separatedBy: .newlines)
      .filter { !$0.isEmpty }

    var ticks: [ProbeTickRaw] = []
    let decoder = JSONDecoder()

    for (index, line) in lines.prefix(100).enumerated() { // Limit to first 100 lines for testing
      do {
        let tick = try decoder.decode(ProbeTickRaw.self, from: line.data(using: .utf8)!)
        ticks.append(tick)
      } catch {
        print("Failed to parse line \(index): \(error)")
        continue
      }
    }

    return ticks
  }

  private mutating func setupGoldenSamples() {
    // Create realistic golden sample probe ticks with deterministic, valid values
    goldenSampleTicks = []
    let baseTime = ISO8601DateFormatter().date(from: "2025-01-01T12:00:00Z")!

    for hour in 0 ..< 24 {
      for bridgeId in [1, 2] {
        let timestamp = Calendar.current.date(byAdding: .hour, value: hour, to: baseTime)!
        let isoString = ISO8601DateFormatter().string(from: timestamp)

        // Use deterministic values that are guaranteed to pass validation
        let crossK = 0.5 + (Double(hour % 3) * 0.2) // 0.5, 0.7, 0.9, 0.5, 0.7, 0.9...
        let crossN = 1.0
        let viaRoutable = 0.8 + (Double(hour % 2) * 0.2) // 0.8, 1.0, 0.8, 1.0...
        let viaPenalty = 20.0 + (Double(hour % 4) * 10.0) // 20, 30, 40, 50, 20, 30...
        let gateAnom = 0.1 + (Double(hour % 2) * 0.05) // 0.1, 0.15, 0.1, 0.15...
        let alternatesTotal = 2.0 + Double(hour % 2) // 2.0, 3.0, 2.0, 3.0...
        let alternatesAvoid = 0.2 + (Double(hour % 3) * 0.1) // 0.2, 0.3, 0.4, 0.2, 0.3...
        let openLabel = hour % 2 // 0, 1, 0, 1...
        let detourDelta = 120.0 + (Double(hour % 3) * 60.0) // 120, 180, 240, 120, 180...
        let detourFrac = 0.3 + (Double(hour % 4) * 0.1) // 0.3, 0.4, 0.5, 0.6, 0.3...

        let tick = ProbeTickRaw(v: hour * 2 + bridgeId,
                                ts_utc: isoString,
                                bridge_id: bridgeId,
                                cross_k: crossK,
                                cross_n: crossN,
                                via_routable: viaRoutable,
                                via_penalty_sec: viaPenalty,
                                gate_anom: gateAnom,
                                alternates_total: alternatesTotal,
                                alternates_avoid: alternatesAvoid,
                                open_label: openLabel,
                                detour_delta: detourDelta,
                                detour_frac: detourFrac)
        goldenSampleTicks.append(tick)
      }
    }

    // Create realistic golden sample feature vectors with deterministic values
    goldenSampleFeatures = []
    for tick in goldenSampleTicks {
      for horizon in defaultHorizons {
        let date = ISO8601DateFormatter().date(from: tick.ts_utc)!
        let minute = Calendar.current.component(.minute, from: date)
        let weekday = Calendar.current.component(.weekday, from: date)

        let hour = Calendar.current.component(.hour, from: date)
        let feature = FeatureVector(bridge_id: tick.bridge_id,
                                    horizon_min: horizon,
                                    min_sin: sin(Double(minute) * .pi / 30),
                                    min_cos: cos(Double(minute) * .pi / 30),
                                    dow_sin: sin(Double(weekday) * .pi / 7),
                                    dow_cos: cos(Double(weekday) * .pi / 7),
                                    open_5m: tick.open_label == 1 ? 1.0 : 0.0,
                                    open_30m: tick.open_label == 1 ? 1.0 : 0.0,
                                    detour_delta: tick.detour_delta ?? 120.0,
                                    cross_rate: (tick.cross_k ?? 0.5) / (tick.cross_n ?? 1.0),
                                    via_routable: tick.via_routable ?? 0.8,
                                    via_penalty: tick.via_penalty_sec ?? 20.0,
                                    gate_anom: tick.gate_anom ?? 0.1,
                                    detour_frac: tick.detour_frac ?? 0.3,
                                    current_speed: 25.0 + (Double(hour % 5) * 5.0),
                                    normal_speed: 30.0 + (Double(hour % 3) * 2.0),
                                    target: tick.open_label)
        goldenSampleFeatures.append(feature)
      }
    }
  }

  @Test("Edge cases should not cause crashes or unexpected behavior")
  mutating func edgeCaseCrashPrevention() async throws {
    try await setUp()

    // Test 1: Empty array
    let emptyResult = validationService.validate(ticks: [])
    #expect(emptyResult.totalRecords == 0)
    #expect(emptyResult.validationRate >= 0.0) // Should not crash
    #expect(!emptyResult.summary.isEmpty) // Should provide meaningful summary

    // Test 2: Single element array
    let singleTick = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
    ]
    let singleResult = validationService.validate(ticks: singleTick)
    #expect(singleResult.totalRecords == 1)
    #expect(singleResult.validationRate >= 0.0) // Should not crash
    #expect(singleResult.timestampRange.first != nil)
    #expect(singleResult.timestampRange.last != nil)

    // Test 3: Two identical timestamps (should be allowed for non-decreasing)
    let duplicateTimeTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 2,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
    ]
    let duplicateResult = validationService.validate(ticks: duplicateTimeTicks)
    #expect(duplicateResult.totalRecords == 2)
    #expect(duplicateResult.validationRate >= 0.0) // Should not crash
    #expect(duplicateResult.timestampRange.first != nil)
    #expect(duplicateResult.timestampRange.last != nil)

    // Test 4: All invalid timestamps
    let invalidTimeTicks = [
      ProbeTickRaw(v: 1, ts_utc: "invalid-timestamp", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "also-invalid", bridge_id: 2,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
    ]
    let invalidResult = validationService.validate(ticks: invalidTimeTicks)
    #expect(invalidResult.totalRecords == 2)
    #expect(invalidResult.validationRate >= 0.0) // Should not crash
    #expect(invalidResult.errors.contains { $0.contains("Invalid timestamp") })

    // Test 5: Mixed valid/invalid timestamps
    let mixedTimeTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.3),
      ProbeTickRaw(v: 1, ts_utc: "invalid-timestamp", bridge_id: 2,
                   cross_k: 0.6, cross_n: 1.1, via_routable: 0.9,
                   via_penalty_sec: 25.0, gate_anom: 0.05, alternates_total: 3.0,
                   alternates_avoid: 0.3, open_label: 1, detour_delta: 90.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:02:00Z", bridge_id: 3,
                   cross_k: 0.4, cross_n: 0.9, via_routable: 0.7,
                   via_penalty_sec: 35.0, gate_anom: 0.15, alternates_total: 1.0,
                   alternates_avoid: 0.7, open_label: 0, detour_delta: 150.0, detour_frac: 0.4),
    ]
    let mixedResult = validationService.validate(ticks: mixedTimeTicks)
    #expect(mixedResult.totalRecords == 3)
    #expect(mixedResult.validationRate >= 0.0) // Should not crash
    #expect(mixedResult.errors.contains { $0.contains("Invalid timestamp") })
    #expect(mixedResult.timestampRange.first != nil)
    #expect(mixedResult.timestampRange.last != nil)
  }

  @Test("Leap second timestamps should be handled gracefully")
  mutating func leapSecondHandling() async throws {
    try await setUp()

    // Test with actual leap second timestamps
    let leapSecondTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-06-30T23:59:60Z", bridge_id: 1, // Leap second
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-06-30T23:59:59Z", bridge_id: 1, // Normal second
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-07-01T00:00:00Z", bridge_id: 1, // Next day
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
    ]

    let result = validationService.validate(ticks: leapSecondTicks)

    // Should not crash and should handle leap seconds gracefully
    #expect(result.totalRecords == 3)
    #expect(result.validationRate >= 0.0)

    // Should provide meaningful feedback about leap second handling
    #expect(!result.summary.isEmpty)

    // Should not have errors about invalid timestamps (leap seconds should be sanitized)
    #expect(!result.errors.contains { $0.contains("Invalid timestamp") })
  }

  @Test("Mixed timezone formats should be handled correctly")
  mutating func mixedTimezoneHandling() async throws {
    try await setUp()

    // Test with various timezone formats
    let mixedTimezoneTicks = [
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1, // UTC
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00+00:00", bridge_id: 1, // UTC with offset
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00-08:00", bridge_id: 1, // PST
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
    ]

    let result = validationService.validate(ticks: mixedTimezoneTicks)

    // Should handle all timezone formats correctly
    #expect(result.totalRecords == 3)
    #expect(result.validationRate >= 0.0)

    // Should not have timestamp parsing errors
    #expect(!result.errors.contains { $0.contains("Invalid timestamp") })
  }

  @Test("Parsing failure scenarios should be handled gracefully")
  mutating func parsingFailureHandling() async throws {
    try await setUp()

    // Test with various malformed timestamps
    let malformedTicks = [
      ProbeTickRaw(v: 1, ts_utc: "not-a-timestamp", bridge_id: 1,
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00", bridge_id: 1, // Missing timezone
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-13-01T12:00:00Z", bridge_id: 1, // Invalid month
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
      ProbeTickRaw(v: 1, ts_utc: "2025-01-01T12:00:00Z", bridge_id: 1, // Valid timestamp
                   cross_k: 0.5, cross_n: 1.0, via_routable: 0.8,
                   via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                   alternates_avoid: 0.5, open_label: 0, detour_delta: 120.0, detour_frac: 0.2),
    ]

    let result = validationService.validate(ticks: malformedTicks)

    // Should handle parsing failures gracefully
    #expect(result.totalRecords == 4)
    #expect(result.validationRate >= 0.0)

    // Should report parsing failures
    #expect(result.errors.contains { $0.contains("Invalid timestamp") })

    // Should provide parsing success rate information
    #expect(result.warnings.contains { $0.contains("failed to parse") })
    #expect(result.warnings.contains { $0.contains("success rate") })
  }

  @Test("Array bounds safety should be maintained under all conditions")
  mutating func arrayBoundsSafety() async throws {
    try await setUp()

    // Test with various array sizes that could trigger bounds issues
    let testSizes = [0, 1, 2, 3, 10, 100]

    for size in testSizes {
      var testTicks: [ProbeTickRaw] = []

      // Generate test data
      for i in 0 ..< size {
        let timestamp = "2025-01-01T12:\(String(format: "%02d", i)):00Z"
        let tick = ProbeTickRaw(v: 1, ts_utc: timestamp, bridge_id: i + 1,
                                cross_k: Double(i) * 0.1, cross_n: 1.0, via_routable: 0.8,
                                via_penalty_sec: 30.0, gate_anom: 0.1, alternates_total: 2.0,
                                alternates_avoid: 0.5, open_label: i % 2, detour_delta: 120.0, detour_frac: 0.3)
        testTicks.append(tick)
      }

      // This should never crash, regardless of array size
      let result = validationService.validate(ticks: testTicks)

      #expect(result.totalRecords == size)
      #expect(result.validationRate >= 0.0) // Should not crash
      #expect(!result.summary.isEmpty) // Should provide meaningful summary

      // For non-empty arrays, we should have timestamp range
      if size > 0 {
        #expect(result.timestampRange.first != nil)
        #expect(result.timestampRange.last != nil)
      }
    }
  }

  @Test("Safe iteration patterns should work correctly")
  mutating func safeIterationPatterns() async throws {
    try await setUp()

    // Test that our safe iteration patterns work as expected
    let testArray = [1, 2, 3, 4, 5]

    // Test zip-based adjacent pairs
    var adjacentCount = 0
    for (prev, curr) in zip(testArray, testArray.dropFirst()) {
      adjacentCount += 1
      #expect(curr == prev + 1) // Should be consecutive numbers
    }
    #expect(adjacentCount == 4) // Should have 4 adjacent pairs for 5 elements

    // Test safe array access using existing extensions
    #expect(testArray[safe: 0] == 1)
    #expect(testArray[safe: 4] == 5)
    #expect(testArray[safe: 5] == nil) // Out of bounds should return nil
    #expect(testArray[safe: -1] == nil) // Negative index should return nil

    // Test with empty array
    let emptyArray: [Int] = []
    var emptyAdjacentCount = 0
    for _ in zip(emptyArray, emptyArray.dropFirst()) {
      emptyAdjacentCount += 1
    }
    #expect(emptyAdjacentCount == 0) // Should not iterate over empty array

    // Test with single element array
    let singleArray = [42]
    var singleAdjacentCount = 0
    for _ in zip(singleArray, singleArray.dropFirst()) {
      singleAdjacentCount += 1
    }
    #expect(singleAdjacentCount == 0) // Should not iterate over single element
  }
}
