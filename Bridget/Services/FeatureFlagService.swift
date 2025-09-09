//
//  FeatureFlagService.swift
//  Bridget
//
//  Purpose: Manages feature flags for gradual rollout and A/B testing
//  Dependencies: Foundation
//  Integration Points:
//    - Used by CoordinateTransformService for gradual rollout
//    - Used by BridgeRecordValidator for A/B testing
//    - Configurable via configuration files and remote settings
//  Key Features:
//    - Gradual rollout percentages (10%, 50%, 100%)
//    - A/B testing between old and new implementations
//    - Feature flag persistence and monitoring
//    - Rollback capabilities for safety
//

import Foundation

// MARK: - Feature Flag Types

/// Represents different feature flags in the application
public enum FeatureFlag: String, CaseIterable, Codable, Sendable {
  case coordinateTransformation = "coordinate_transformation"
  case enhancedValidation = "enhanced_validation"
  case statisticalUncertainty = "statistical_uncertainty"
  case trafficProfileIntegration = "traffic_profile_integration"

  public var description: String {
    switch self {
    case .coordinateTransformation:
      return "Coordinate Transformation System"
    case .enhancedValidation:
      return "Enhanced Bridge Record Validation"
    case .statisticalUncertainty:
      return "Statistical Uncertainty Quantification"
    case .trafficProfileIntegration:
      return "Traffic Profile Integration"
    }
  }
}

/// Represents the rollout percentage for a feature
public enum RolloutPercentage: Int, CaseIterable, Codable, Sendable {
  case disabled = 0
  case tenPercent = 10
  case twentyFivePercent = 25
  case fiftyPercent = 50
  case seventyFivePercent = 75
  case oneHundredPercent = 100

  public var description: String {
    switch self {
    case .disabled:
      return "Disabled (0%)"
    case .tenPercent:
      return "10% Rollout"
    case .twentyFivePercent:
      return "25% Rollout"
    case .fiftyPercent:
      return "50% Rollout"
    case .seventyFivePercent:
      return "75% Rollout"
    case .oneHundredPercent:
      return "100% Rollout (Full)"
    }
  }
}

/// Represents the A/B testing variant
public enum ABTestVariant: String, CaseIterable, Codable, Sendable {
  case control  // Old implementation
  case treatment  // New implementation

  public var description: String {
    switch self {
    case .control:
      return "Control (Current)"
    case .treatment:
      return "Treatment (New)"
    }
  }
}

// MARK: - Feature Flag Configuration

/// Configuration for a feature flag
public struct FeatureFlagConfig: Codable, Equatable, Sendable {
  public let flag: FeatureFlag
  public let enabled: Bool
  public let rolloutPercentage: RolloutPercentage
  public let abTestEnabled: Bool
  public let abTestVariant: ABTestVariant?
  public let startDate: Date?
  public let endDate: Date?
  public let metadata: [String: String]

  public init(flag: FeatureFlag,
              enabled: Bool = false,
              rolloutPercentage: RolloutPercentage = .disabled,
              abTestEnabled: Bool = false,
              abTestVariant: ABTestVariant? = nil,
              startDate: Date? = nil,
              endDate: Date? = nil,
              metadata: [String: String] = [:])
  {
    self.flag = flag
    self.enabled = enabled
    self.rolloutPercentage = rolloutPercentage
    self.abTestEnabled = abTestEnabled
    self.abTestVariant = abTestVariant
    self.startDate = startDate
    self.endDate = endDate
    self.metadata = metadata
  }

  /// Check if the feature flag is currently active
  public var isActive: Bool {
    guard enabled else { return false }

    // Check date range if specified
    let now = Date()
    if let startDate = startDate, now < startDate { return false }
    if let endDate = endDate, now > endDate { return false }

    return true
  }

  /// Check if A/B testing is active
  public var isABTestActive: Bool {
    return abTestEnabled && abTestVariant != nil && isActive
  }
}

// MARK: - Feature Flag Service

/// Service for managing feature flags and gradual rollout
@preconcurrency
public protocol FeatureFlagService {
  /// Get the configuration for a specific feature flag
  @MainActor func getConfig(for flag: FeatureFlag) -> FeatureFlagConfig

  /// Check if a feature flag is enabled for a specific user/bridge
  @MainActor func isEnabled(_ flag: FeatureFlag, for identifier: String)
    -> Bool

  /// Get the A/B test variant for a specific user/bridge
  @MainActor func getABTestVariant(_ flag: FeatureFlag,
                                   for identifier: String) -> ABTestVariant?

  /// Update feature flag configuration
  @MainActor func updateConfig(_ config: FeatureFlagConfig) throws

  /// Get all feature flag configurations
  @MainActor func getAllConfigs() -> [FeatureFlag: FeatureFlagConfig]

  /// Reset feature flags to defaults
  @MainActor func resetToDefaults()
}

// MARK: - Default Feature Flag Service

/// Default implementation of the feature flag service
@MainActor
public final class DefaultFeatureFlagService: FeatureFlagService, Sendable {
  private var configs: [FeatureFlag: FeatureFlagConfig]
  private let userDefaults: UserDefaults
  private let configKey = "BridgetFeatureFlags"

  private static var isRunningInTests: Bool {
    NSClassFromString("XCTest") != nil
  }

  public init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    // In tests, always start from default configs to avoid interference from persisted state
    if Self.isRunningInTests {
      self.configs = [:]
      self.configs = createDefaultConfigs()
      return
    }

    if let data = userDefaults.data(forKey: configKey),
       let decoded = try? JSONDecoder().decode([FeatureFlag: FeatureFlagConfig].self,
                                               from: data)
    {
      self.configs = decoded
    } else {
      self.configs = [:]
      self.configs = createDefaultConfigs()
    }
  }

  public func getConfig(for flag: FeatureFlag) -> FeatureFlagConfig {
    return configs[flag] ?? FeatureFlagConfig(flag: flag)
  }

  public func isEnabled(_ flag: FeatureFlag, for identifier: String) -> Bool {
    let config = getConfig(for: flag)

    // Check if feature is active
    guard config.isActive else { return false }

    // If A/B testing is enabled, use A/B test logic
    if config.isABTestActive {
      return getABTestVariant(flag, for: identifier) == .treatment
    }

    // Use rollout percentage logic
    let hash = abs(identifier.hashValue)
    let percentage = hash % 100
    return percentage < config.rolloutPercentage.rawValue
  }

  public func getABTestVariant(_ flag: FeatureFlag, for identifier: String)
    -> ABTestVariant?
  {
    let config = getConfig(for: flag)

    guard config.isABTestActive else { return nil }

    // Use consistent hashing to ensure same user gets same variant
    let hash = abs(identifier.hashValue)
    return hash % 2 == 0 ? .control : .treatment
  }

  public func updateConfig(_ config: FeatureFlagConfig) throws {
    configs[config.flag] = config
    saveConfigs()
  }

  public func getAllConfigs() -> [FeatureFlag: FeatureFlagConfig] {
    return configs
  }

  public func resetToDefaults() {
    configs = createDefaultConfigs()
    saveConfigs()
  }

  // MARK: - Private Methods

  private func saveConfigs() {
    if let data = try? JSONEncoder().encode(configs) {
      userDefaults.set(data, forKey: configKey)
    }
  }

  private func createDefaultConfigs() -> [FeatureFlag: FeatureFlagConfig] {
    var configs: [FeatureFlag: FeatureFlagConfig] = [:]

    // Default configuration for coordinate transformation
    configs[.coordinateTransformation] = FeatureFlagConfig(flag: .coordinateTransformation,
                                                           enabled: true,  // Enable coordinate transformation
                                                           rolloutPercentage: .oneHundredPercent,  // 100% rollout
                                                           abTestEnabled: false,
                                                           metadata: [
                                                             "description": "Coordinate transformation system enabled",
                                                             "phase": "4.1",
                                                             "safety_level": "high",
                                                             "enabled_at": ISO8601DateFormatter().string(from: Date()),
                                                           ])

    // Default configuration for other features
    for flag in FeatureFlag.allCases where flag != .coordinateTransformation {
      configs[flag] = FeatureFlagConfig(flag: flag)
    }

    return configs
  }
}

// MARK: - Feature Flag Extensions

public extension DefaultFeatureFlagService {
  /// Shared instance for easy access
  ///
  /// In test environments, this uses a dedicated UserDefaults suite and resets to defaults
  /// to ensure the coordinate transformation flag is enabled at 100% regardless of prior state.
  static let shared: DefaultFeatureFlagService = {
    if DefaultFeatureFlagService.isRunningInTests {
      let testDefaults =
        UserDefaults(suiteName: "BridgetTests") ?? .standard
      let service = DefaultFeatureFlagService(userDefaults: testDefaults)
      service.resetToDefaults()  // Guarantees coordinateTransformation is enabled at 100%
      return service
    } else {
      return DefaultFeatureFlagService()
    }
  }()

  /// Enable coordinate transformation with specific rollout percentage
  func enableCoordinateTransformation(
    rolloutPercentage: RolloutPercentage
  ) {
    let config = FeatureFlagConfig(flag: .coordinateTransformation,
                                   enabled: true,
                                   rolloutPercentage: rolloutPercentage,
                                   metadata: [
                                     "description":
                                       "Coordinate transformation enabled with \(rolloutPercentage.description)",
                                     "enabled_at": ISO8601DateFormatter().string(from: Date()),
                                     "rollout_percentage": "\(rolloutPercentage.rawValue)%",
                                   ])

    try? updateConfig(config)
  }

  /// Enable A/B testing for coordinate transformation
  func enableCoordinateTransformationABTest() {
    let config = FeatureFlagConfig(flag: .coordinateTransformation,
                                   enabled: true,
                                   rolloutPercentage: .fiftyPercent,  // 50% for A/B testing
                                   abTestEnabled: true,
                                   metadata: [
                                     "description":
                                       "A/B testing enabled for coordinate transformation",
                                     "enabled_at": ISO8601DateFormatter().string(from: Date()),
                                     "test_type": "ab_test",
                                   ])

    try? updateConfig(config)
  }

  /// Disable coordinate transformation (rollback)
  func disableCoordinateTransformation() {
    let config = FeatureFlagConfig(flag: .coordinateTransformation,
                                   enabled: false,
                                   rolloutPercentage: .disabled,
                                   abTestEnabled: false,
                                   metadata: [
                                     "description": "Coordinate transformation disabled (rollback)",
                                     "disabled_at": ISO8601DateFormatter().string(from: Date()),
                                     "reason": "rollback",
                                   ])

    try? updateConfig(config)
  }
}
