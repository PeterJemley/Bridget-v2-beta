import Foundation

/// Runtime guardrails for preventing accidental cross-context access.
/// Use only for debug-time assertions (no production behavior changes).
public enum RuntimeGuards {
  /// Set to true when rendering metrics dashboards or other contexts
  /// that must not touch Core ML or heavy model-loading paths.
  public static var metricsOnlyContext: Bool = false

  /// Namespaced assertion helper for easier cross-target visibility
  @inline(__always)
  public static func assertNotInMetricsContext(_ whereAmI: @autoclosure () -> String) {
    #if DEBUG
    if RuntimeGuards.metricsOnlyContext {
      assertionFailure("Core ML accessed during metrics-only context at \(whereAmI())")
    }
    #endif
  }
}

/// Assert that we are not in metrics-only context when calling ML entry points.
@inline(__always)
public func assertNotInMetricsContext(_ whereAmI: @autoclosure () -> String) {
  #if DEBUG
  if RuntimeGuards.metricsOnlyContext {
    assertionFailure("Core ML accessed during metrics-only context at \(whereAmI())")
  }
  #endif
}

