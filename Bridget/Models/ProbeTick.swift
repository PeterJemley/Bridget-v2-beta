//
//  ProbeTick.swift
//  Bridget
//
//  Purpose: SwiftData model for per-minute, per-bridge probe snapshot required for ML export and analytics.
//

import Foundation
import SwiftData

/// SwiftData model for bridge probe tick: one row per bridge per minute.
///
/// `ProbeTick` represents a snapshot of bridge conditions at a specific minute,
/// capturing real-time metrics that are used for machine learning training and
/// bridge lift prediction. Each record contains bridge status, traffic patterns,
/// and routing information.
///
/// ## Usage
///
/// ```swift
/// // Create a new probe tick
/// let tick = ProbeTick(
///     tsUtc: Date(),
///     bridgeId: 1,
///     crossK: 5,
///     crossN: 10,
///     viaRoutable: true,
///     viaPenaltySec: 120,
///     gateAnom: 2.5,
///     alternatesTotal: 3,
///     alternatesAvoid: 1,
///     openLabel: false
/// )
///
/// // Save to SwiftData
/// context.insert(tick)
/// ```
///
/// ## ML Training Features
///
/// This model provides the raw data for the following ML features:
/// - `cross_rate_1m`: `crossK / crossN` (vehicle crossing rate)
/// - `via_routable`: Boolean flag for alternative routing
/// - `via_penalty`: Normalized penalty for via routing
/// - `gate_anom`: Gate ETA anomaly ratio
/// - `detour_frac`: Fraction of routes avoiding the bridge
///
/// ## Data Validation
///
/// The model includes validation fields:
/// - `isValid`: General data quality flag
/// - `openLabel`: Debounced/HMM state for bridge opening
///
/// - Note: `viaPenaltySec` is clipped to [0, 900] seconds
/// - Note: `gateAnom` is clipped to [1, 8] ratio
@Model
final class ProbeTick {
  /// Unique identifier for this probe tick record
  @Attribute(.unique) var id: UUID

  /// UTC timestamp when this probe was recorded
  var tsUtc: Date

  /// Bridge identifier (maps to BridgeID enum)
  var bridgeId: Int16

  /// Number of vehicles that crossed the bridge this minute
  var crossK: Int16

  /// Total number of vehicles that attempted to cross this minute
  var crossN: Int16

  /// Whether the bridge can be used as a via route
  var viaRoutable: Bool

  /// Penalty in seconds for using this bridge as a via route (clipped [0,900])
  var viaPenaltySec: Int32

  /// Gate ETA anomaly ratio compared to historical baseline (clipped [1,8])
  var gateAnom: Double

  /// Total number of alternative routes available
  var alternatesTotal: Int16

  /// Number of alternative routes that avoid this bridge span
  var alternatesAvoid: Int16

  /// ETA in seconds for the free route (optional)
  var freeEtaSec: Int32?

  /// ETA in seconds for the via route (optional)
  var viaEtaSec: Int32?

  /// Bridge opening state from debounced/HMM processing
  var openLabel: Bool

  /// Data quality validation flag
  var isValid: Bool

  /// Creates a new probe tick record
  /// - Parameters:
  ///   - id: Unique identifier (defaults to new UUID)
  ///   - tsUtc: UTC timestamp when probe was recorded
  ///   - bridgeId: Bridge identifier
  ///   - crossK: Number of vehicles that crossed
  ///   - crossN: Total vehicles that attempted to cross
  ///   - viaRoutable: Whether bridge can be used as via route
  ///   - viaPenaltySec: Penalty in seconds for via routing
  ///   - gateAnom: Gate ETA anomaly ratio
  ///   - alternatesTotal: Total alternative routes
  ///   - alternatesAvoid: Routes avoiding this bridge
  ///   - freeEtaSec: ETA for free route (optional)
  ///   - viaEtaSec: ETA for via route (optional)
  ///   - openLabel: Bridge opening state
  ///   - isValid: Data quality flag (defaults to true)
  init(id: UUID = UUID(),
       tsUtc: Date,
       bridgeId: Int16,
       crossK: Int16,
       crossN: Int16,
       viaRoutable: Bool,
       viaPenaltySec: Int32,
       gateAnom: Double,
       alternatesTotal: Int16,
       alternatesAvoid: Int16,
       freeEtaSec: Int32? = nil,
       viaEtaSec: Int32? = nil,
       openLabel: Bool,
       isValid: Bool = true)
  {
    self.id = id
    self.tsUtc = tsUtc
    self.bridgeId = bridgeId
    self.crossK = crossK
    self.crossN = crossN
    self.viaRoutable = viaRoutable
    self.viaPenaltySec = viaPenaltySec
    self.gateAnom = gateAnom
    self.alternatesTotal = alternatesTotal
    self.alternatesAvoid = alternatesAvoid
    self.freeEtaSec = freeEtaSec
    self.viaEtaSec = viaEtaSec
    self.openLabel = openLabel
    self.isValid = isValid
  }
}
