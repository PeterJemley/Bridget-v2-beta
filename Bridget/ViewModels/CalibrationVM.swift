import Foundation
import Observation
import SwiftUI

/// Replace with your real calibrator implementation, which should provide async calibration for a bridge.
protocol BridgeCalibrator {
  func discoverCrossRoute(bridge: BridgeStatusModel) async throws -> CrossRouteResult
}

// Stub structs for compilation - replace with real result types
struct CrossRouteResult {
  let quality: CrossRouteQuality
  let lastValidatedAt: Date
}

struct CrossRouteQuality {
  let minCenterDistanceM: Double
  let sampleCount: Int
  let geocodeConfidence: Double
}

@Observable
final class CalibrationVM {
  enum RowState {
    case pending, running, success
    case error(String)
  }

  struct Row: Identifiable {
    let id: String
    let name: String
    var state: RowState = .pending
    var qualityText: String = ""
    var lastValidated: Date?
  }

  var rows: [Row] = []
  var overallProgress: Double = 0
  var isRunning = false

  private let calibrator: BridgeCalibrator
  private let bridges: [BridgeStatusModel]

  init(calibrator: BridgeCalibrator, bridges: [BridgeStatusModel]) {
    self.calibrator = calibrator
    self.bridges = bridges
    self.rows = bridges.map {
      .init(id: $0.apiBridgeID?.rawValue ?? $0.bridgeName, name: $0.bridgeName)
    }
  }

  @MainActor
  func start(force _: Bool = false) {
    guard !isRunning else { return }
    isRunning = true
    overallProgress = 0
    rows.indices.forEach { rows[$0].state = .pending }

    Task {
      let total = bridges.count
      var completed = 0
      for (i, b) in bridges.enumerated() {
        await MainActor.run { rows[i].state = .running }
        do {
          let cr = try await calibrator.discoverCrossRoute(bridge: b)
          let q = String(
            format: "center=%.0fm, n=%d, geo=%.2f",
            cr.quality.minCenterDistanceM, cr.quality.sampleCount, cr.quality.geocodeConfidence)
          await MainActor.run {
            rows[i].state = .success
            rows[i].qualityText = q
            rows[i].lastValidated = cr.lastValidatedAt
            completed += 1
            overallProgress = Double(completed) / Double(total)
          }
        } catch {
          await MainActor.run {
            rows[i].state = .error(error.localizedDescription)
            completed += 1
            overallProgress = Double(completed) / Double(total)
          }
        }
      }
      await MainActor.run { isRunning = false }
    }
  }
}

/// Sample calibrator implementation for development and testing.
/// Replace with your real calibration logic.
final class DefaultBridgeCalibrator: BridgeCalibrator {
  func discoverCrossRoute(bridge _: BridgeStatusModel) async throws -> CrossRouteResult {
    // Replace this mock logic with real calibration/calculation/ML, etc.
    let simulatedQuality = CrossRouteQuality(
      minCenterDistanceM: Double.random(in: 20...100),
      sampleCount: Int.random(in: 10...100),
      geocodeConfidence: Double.random(in: 0.7...1.0))
    // Simulate calibration time
    try await Task.sleep(nanoseconds: 300_000_000)  // 0.3 seconds
    return CrossRouteResult(quality: simulatedQuality, lastValidatedAt: Date())
  }
}
