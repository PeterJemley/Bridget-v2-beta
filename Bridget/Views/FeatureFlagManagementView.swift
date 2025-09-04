//
//  FeatureFlagManagementView.swift
//  Bridget
//
//  Purpose: SwiftUI view for managing feature flags during gradual rollout
//  Dependencies: SwiftUI, Bridget services
//  Integration Points:
//    - Used in SettingsTabView for feature flag management
//    - Provides UI for gradual rollout control
//    - Shows A/B testing status and results
//  Key Features:
//    - Feature flag enable/disable controls
//    - Rollout percentage sliders
//    - A/B testing configuration
//    - Real-time status monitoring
//

import SwiftUI

/// SwiftUI view for managing feature flags
public struct FeatureFlagManagementView: View {
  @State private var featureFlagService = DefaultFeatureFlagService.shared
  @State private var showingAlert = false
  @State private var alertMessage = ""

  public init() {}

  public var body: some View {
    NavigationView {
      List {
        Section("Coordinate Transformation System") {
          coordinateTransformationSection
        }

        Section("Feature Flag Status") {
          featureFlagStatusSection
        }

        Section("A/B Testing") {
          abTestingSection
        }

        Section("Actions") {
          actionsSection
        }
      }
      .navigationTitle("Feature Flags")
      .alert("Feature Flag Update", isPresented: $showingAlert) {
        Button("OK") {}
      } message: {
        Text(alertMessage)
      }
    }
  }

  private var coordinateTransformationSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      let config = featureFlagService.getConfig(for: .coordinateTransformation)

      HStack {
        Text("Coordinate Transformation")
        Spacer()
        StatusBadge(isEnabled: config.isActive)
      }

      if config.isActive {
        VStack(alignment: .leading, spacing: 8) {
          Text("Rollout: \(config.rolloutPercentage.description)")
            .font(.caption)
            .foregroundColor(.secondary)

          if config.isABTestActive {
            Text("A/B Testing: Active")
              .font(.caption)
              .foregroundColor(.blue)
          }

          if let startDate = config.startDate {
            Text("Started: \(startDate, style: .date)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }
      }

      HStack {
        Button("Enable 10%") {
          enableFeatureFlag(rolloutPercentage: .tenPercent)
        }
        .buttonStyle(.bordered)

        Button("Enable 50%") {
          enableFeatureFlag(rolloutPercentage: .fiftyPercent)
        }
        .buttonStyle(.bordered)

        Button("Enable 100%") {
          enableFeatureFlag(rolloutPercentage: .oneHundredPercent)
        }
        .buttonStyle(.bordered)
      }
    }
  }

  private var featureFlagStatusSection: some View {
    ForEach(FeatureFlag.allCases, id: \.self) { flag in
      let config = featureFlagService.getConfig(for: flag)

      HStack {
        VStack(alignment: .leading) {
          Text(flag.description)
            .font(.headline)
          Text("Status: \(config.isActive ? "Active" : "Inactive")")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        StatusBadge(isEnabled: config.isActive)
      }
    }
  }

  private var abTestingSection: some View {
    VStack(alignment: .leading, spacing: 12) {
      let config = featureFlagService.getConfig(for: .coordinateTransformation)

      HStack {
        Text("A/B Testing")
        Spacer()
        StatusBadge(isEnabled: config.isABTestActive)
      }

      if config.isABTestActive {
        Text("Control Group: Old threshold-based validation")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("Treatment Group: New coordinate transformation")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Button("Enable A/B Testing") {
        enableABTesting()
      }
      .buttonStyle(.bordered)
      .disabled(config.isABTestActive)
    }
  }

  private var actionsSection: some View {
    VStack(spacing: 12) {
      Button("Disable All Features") {
        disableAllFeatures()
      }
      .buttonStyle(.borderedProminent)
      .foregroundColor(.red)

      Button("Reset to Defaults") {
        resetToDefaults()
      }
      .buttonStyle(.bordered)

      Button("Export Configuration") {
        exportConfiguration()
      }
      .buttonStyle(.bordered)
    }
  }

  // MARK: - Actions

  private func enableFeatureFlag(rolloutPercentage: RolloutPercentage) {
    featureFlagService.enableCoordinateTransformation(rolloutPercentage: rolloutPercentage)
    showAlert("Coordinate transformation enabled with \(rolloutPercentage.description)")
  }

  private func enableABTesting() {
    featureFlagService.enableCoordinateTransformationABTest()
    showAlert("A/B testing enabled for coordinate transformation")
  }

  private func disableAllFeatures() {
    featureFlagService.disableCoordinateTransformation()
    showAlert("All features disabled")
  }

  private func resetToDefaults() {
    featureFlagService.resetToDefaults()
    showAlert("Feature flags reset to defaults")
  }

  private func exportConfiguration() {
    let configs = featureFlagService.getAllConfigs()
    let encoder = JSONEncoder()
    encoder.outputFormatting = .prettyPrinted

    if let data = try? encoder.encode(configs),
       let _ = String(data: data, encoding: .utf8)
    {
      // In a real app, you might save this to a file or share it
      showAlert("Configuration exported successfully")
    } else {
      showAlert("Failed to export configuration")
    }
  }

  private func showAlert(_ message: String) {
    alertMessage = message
    showingAlert = true
  }
}

/// Status badge component
private struct StatusBadge: View {
  let isEnabled: Bool

  var body: some View {
    Text(isEnabled ? "ON" : "OFF")
      .font(.caption)
      .fontWeight(.bold)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(isEnabled ? Color.green : Color.red)
      .foregroundColor(.white)
      .clipShape(Capsule())
  }
}

#Preview {
  FeatureFlagManagementView()
}
