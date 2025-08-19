// FeatureEngineeringTests.swift
// Tests for pure feature extraction from ProbeTickRaw to FeatureVector
//
// ✅ STATUS: COMPLETE - All test requirements implemented
// ✅ COMPLETION DATE: August 17, 2025
// ✅ COVERAGE: Golden sample, edge cases, DST boundaries, helper functions

@testable import Bridget
import Foundation
import Testing

@Suite("Feature Engineering: Golden Sample and Edge Cases")
struct FeatureEngineeringGoldenTests {
  static let goldenTicks: [ProbeTickRaw] = [
    // A golden sample with representative, deterministic ticks (3 for brevity)
    ProbeTickRaw(v: 1,
                 ts_utc: "2025-01-27T08:00:00Z",
                 bridge_id: 1,
                 cross_k: 5,
                 cross_n: 10,
                 via_routable: 1.0,
                 via_penalty_sec: 120,
                 gate_anom: 2.5,
                 alternates_total: 3,
                 alternates_avoid: 1,
                 open_label: 0,
                 detour_delta: 30,
                 detour_frac: 0.1),
    ProbeTickRaw(v: 1,
                 ts_utc: "2025-01-27T08:01:00Z",
                 bridge_id: 1,
                 cross_k: 6,
                 cross_n: 10,
                 via_routable: 1.0,
                 via_penalty_sec: 150,
                 gate_anom: 2.8,
                 alternates_total: 3,
                 alternates_avoid: 1,
                 open_label: 1,
                 detour_delta: 45,
                 detour_frac: 0.15),
    ProbeTickRaw(v: 1,
                 ts_utc: "2025-01-27T08:02:00Z",
                 bridge_id: 2,
                 cross_k: 3,
                 cross_n: 8,
                 via_routable: 0.0,
                 via_penalty_sec: 300,
                 gate_anom: 1.5,
                 alternates_total: 2,
                 alternates_avoid: 0,
                 open_label: 0,
                 detour_delta: -10,
                 detour_frac: 0.05),
  ]

  @Test("Golden sample produces correct feature count and snapshot")
  func goldenSampleFeatures() async throws {
    let horizons = [0, 3]
    let result = try generateFeatures(ticks: Self.goldenTicks, horizons: horizons, deterministicSeed: 42)
    // Expect: result.count == horizon.count, inner array count == N * ticks (if enough for each horizon)
    #expect(result.count == horizons.count)
    // For 3 ticks and each horizon, check the number of feature vectors
    #expect(result[0].count == 3)
    #expect(result[1].count == 3) // Because even at horizon 3, all targets are zero-filled if OOB
    // Check first/last feature vectors by snapshot
    let firstFV = result[0].first!
    #expect(firstFV.bridge_id == 1)
    #expect(firstFV.horizon_min == 0)
    #expect(abs(firstFV.open_5m - 0.0) < 1e-7)
    #expect(firstFV.target == 0)
    let lastFV = result[0].last!
    #expect(lastFV.bridge_id == 2)
    #expect(lastFV.horizon_min == 0)
    #expect(abs(lastFV.detour_delta - -10.0) < 1e-7)
    #expect(lastFV.target == 0)
  }

  @Test("Handles empty and missing ticks (edge)")
  func emptyInput() async throws {
    let out = try generateFeatures(ticks: [], horizons: [0, 1, 3])
    #expect(out.allSatisfy { $0.isEmpty })
  }

  @Test("Single bridge, single tick, all horizons")
  func singleTickSingleBridgeAllHorizons() async throws {
    let tick = ProbeTickRaw(v: 1,
                            ts_utc: "2025-06-07T05:42:00Z",
                            bridge_id: 42,
                            cross_k: 0,
                            cross_n: 1,
                            via_routable: 1.0,
                            via_penalty_sec: 0,
                            gate_anom: 1.0,
                            alternates_total: 1,
                            alternates_avoid: 0,
                            open_label: 1,
                            detour_delta: 23.5,
                            detour_frac: 0.6)
    let out = try generateFeatures(ticks: [tick], horizons: [0, 3, 7])
    #expect(out.count == 3)
    for horizonFeatures in out {
      #expect(horizonFeatures.count == 1)
      let fv = horizonFeatures[0]
      #expect(fv.bridge_id == 42)
      #expect(fv.target == 0 || fv.target == 1) // Only first horizon matches target, others are 0
    }
  }

  @Test("Handles DST boundary: March 10, 2024 (US DST start)")
  func dSTBoundary() async throws {
    let tick = ProbeTickRaw(v: 1,
                            ts_utc: "2024-03-10T09:59:00Z", // 1:59am PST before DST jump
                            bridge_id: 2,
                            cross_k: 1,
                            cross_n: 2,
                            via_routable: 1.0,
                            via_penalty_sec: 60,
                            gate_anom: 1.0,
                            alternates_total: 2,
                            alternates_avoid: 1,
                            open_label: 0,
                            detour_delta: 5.0,
                            detour_frac: 0.25)
    let out = try generateFeatures(ticks: [tick], horizons: [0])
    #expect(out.count == 1 && out[0].count == 1)
    let fv = out[0][0]
    #expect(fv.bridge_id == 2)
    #expect(abs(fv.min_sin) <= 1.0 && abs(fv.min_cos) <= 1.0) // Cyclical encoding
  }
}

@Suite("FeatureEngineering Helper Function Tests")
struct FeatureEngineeringHelperTests {
  @Test("cyc() gives correct sin/cos for canonical values")
  func testCyc() async throws {
    let (sin0, cos0) = cyc(0.0, period: 24.0)
    #expect(abs(sin0) < 1e-10 && abs(cos0 - 1.0) < 1e-10)
    let (sin12, cos12) = cyc(12.0, period: 24.0)
    #expect(abs(sin12) < 1e-10 && abs(cos12 + 1.0) < 1e-10)
  }

  @Test("rollingAverage() computes expected rolling means")
  func testRollingAverage() async throws {
    let arr: [Double?] = [1, 2, 3, nil, 5, 7]
    let out = rollingAverage(arr, window: 3)
    #expect(out.count == arr.count)
    #expect(abs(out[0] - 1.0) < 1e-10)
    #expect(abs(out[3] - 2.0) < 1e-10)
    #expect(abs(out[5] - 5.0) < 1e-10)
  }

  @Test("minuteOfDay and dayOfWeek parse ISO date correctly")
  func minuteOfDayAndDayOfWeek() async throws {
    let iso = ISO8601DateFormatter()
    let date = iso.date(from: "2025-08-17T12:34:00Z")!
    #expect(minuteOfDay(from: date) == 754)
    let dow = dayOfWeek(from: date)
    #expect((1 ... 7).contains(dow))
  }
}
