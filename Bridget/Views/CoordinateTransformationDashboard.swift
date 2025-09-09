//
//  CoordinateTransformationDashboard.swift
//  Bridget
//
//  Purpose: Real-time dashboard for monitoring coordinate transformation performance
//  Dependencies: SwiftUI, Foundation
//  Integration Points:
//    - Uses CoordinateTransformationMonitoringService for data
//    - Uses FeatureFlagMetricsService for feature flag metrics
//    - Displays alerts and performance metrics
//  Key Features:
//    - Real-time metrics display
//    - Alert management
//    - Time range selection
//    - Bridge-specific metrics
//    - Data export functionality
//

import SwiftUI

// MARK: - Main Dashboard View

@MainActor
struct CoordinateTransformationDashboard: View {
  @State private var monitoringService = DefaultCoordinateTransformationMonitoringService.shared
  @State private var featureFlagMetricsService = DefaultFeatureFlagMetricsService.shared
  @State private var currentMetrics: TransformationMetrics?
  @State private var recentAlerts: [AlertEvent] = []
  @State private var selectedTimeRange: TimeRange = .init(startDate: Date().addingTimeInterval(-60 * 60), endDate: Date())
  @State private var showingAlertConfig = false
  @State private var showingExportData = false
  @State private var isLoading = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          headerSection
          metricsSection
          alertsSection
          bridgeMetricsSection
        }
        .padding()
      }
      .navigationTitle("Coordinate Transformation Dashboard")
      .navigationBarTitleDisplayMode(.large)
      .refreshable {
        await loadData()
      }
      .sheet(isPresented: $showingAlertConfig) {
        AlertConfigurationView(monitoringService: monitoringService)
      }
      .sheet(isPresented: $showingExportData) {
        ExportDataView(monitoringService: monitoringService, timeRange: selectedTimeRange)
      }
      .onAppear {
        Task {
          await loadData()
        }
      }
    }
  }

  private var headerSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Monitoring Dashboard")
          .font(.title2)
          .fontWeight(.semibold)
        Spacer()
        Button("Export Data") {
          showingExportData = true
        }
        .buttonStyle(.bordered)
      }

      Picker("Time Range", selection: $selectedTimeRange) {
        Text("Last Hour").tag(TimeRange.lastHour)
        Text("Last 24 Hours").tag(TimeRange.last24Hours)
        Text("Last 7 Days").tag(TimeRange.last7Days)
        Text("Last 30 Days").tag(TimeRange.last30Days)
      }
      .pickerStyle(.segmented)
      .onChange(of: selectedTimeRange) { _, _ in
        Task { @MainActor in
          await loadData()
        }
      }
    }
  }

  private var metricsSection: some View {
    VStack(spacing: 16) {
      Text("Performance Metrics")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      if let metrics = currentMetrics {
        LazyVGrid(columns: [
          GridItem(.flexible()),
          GridItem(.flexible()),
          GridItem(.flexible()),
        ], spacing: 16) {
          DashboardMetricCard(title: "Success Rate",
                              value: String(format: "%.1f%%", metrics.successRate * 100),
                              icon: "checkmark.circle.fill",
                              iconColor: metrics.successRate >= 0.9 ? .green : .orange)

          DashboardMetricCard(title: "Processing Time",
                              value: String(format: "%.2fms", metrics.averageProcessingTimeMs),
                              icon: "clock.fill",
                              iconColor: metrics.averageProcessingTimeMs <= 10.0 ? .green : .orange)

          DashboardMetricCard(title: "Total Events",
                              value: "\(metrics.totalEvents)",
                              icon: "number.circle.fill",
                              iconColor: .blue)
        }

        if let confidence = metrics.averageConfidence {
          DashboardMetricCard(title: "Average Confidence",
                              value: String(format: "%.2f", confidence),
                              icon: "target",
                              iconColor: confidence >= 0.8 ? .green : .orange)
        }
      } else {
        ProgressView("Loading metrics...")
          .frame(maxWidth: .infinity, minHeight: 100)
      }
    }
  }

  private var alertsSection: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Recent Alerts")
          .font(.headline)
        Spacer()
        Button("Configure Alerts") {
          showingAlertConfig = true
        }
        .buttonStyle(.bordered)
      }

      if recentAlerts.isEmpty {
        Text("No alerts in the selected time range")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 60)
      } else {
        ForEach(Array(recentAlerts.enumerated()), id: \.offset) { _, alert in
          AlertRow(alert: alert)
        }
      }
    }
  }

  private var bridgeMetricsSection: some View {
    VStack(spacing: 16) {
      Text("Bridge-Specific Metrics")
        .font(.headline)
        .frame(maxWidth: .infinity, alignment: .leading)

      let bridgeIds = monitoringService.getAllBridgeIds()
      if bridgeIds.isEmpty {
        Text("No bridge data available")
          .foregroundStyle(.secondary)
          .frame(maxWidth: .infinity, minHeight: 60)
      } else {
        ForEach(Array(bridgeIds.prefix(5)), id: \.self) { bridgeId in
          if let bridgeMetrics = monitoringService.getBridgeMetrics(bridgeId: bridgeId, timeRange: selectedTimeRange) {
            BridgeMetricsCard(metrics: bridgeMetrics)
          }
        }
      }
    }
  }

  private func loadData() async {
    isLoading = true
    defer { isLoading = false }

    currentMetrics = monitoringService.getMetrics(timeRange: selectedTimeRange)
    recentAlerts = monitoringService.getRecentAlerts(limit: 10)
  }
}

// MARK: - Supporting Views

struct DashboardMetricCard: View {
  let title: String
  let value: String
  let icon: String
  let iconColor: Color

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: icon)
          .foregroundStyle(iconColor)
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
      }

      Text(value)
        .font(.title2)
        .fontWeight(.semibold)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct AlertRow: View {
  let alert: AlertEvent

  var body: some View {
    HStack {
      Image(systemName: alertIcon)
        .foregroundStyle(alertColor)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 4) {
        Text(alert.message)
          .font(.subheadline)
          .lineLimit(2)

        Text(alert.timestamp, style: .relative)
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var alertIcon: String {
    switch alert.alertType {
    case .lowSuccessRate:
      return "exclamationmark.triangle.fill"
    case .highProcessingTime:
      return "clock.badge.exclamationmark"
    case .lowConfidence:
      return "target"
    case .failureSpike:
      return "bolt.fill"
    case .accuracyDegradation:
      return "chart.line.downtrend.xyaxis"
    }
  }

  private var alertColor: Color {
    switch alert.severity {
    case "critical":
      return .red
    case "warning":
      return .orange
    default:
      return .yellow
    }
  }
}

struct BridgeMetricsCard: View {
  let metrics: BridgeTransformationMetrics

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack {
        Text("Bridge \(metrics.bridgeId)")
          .font(.headline)
        Spacer()
        Text("\(metrics.totalEvents) events")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      HStack {
        PerformanceRow(title: "Success Rate", value: String(format: "%.1f%%", metrics.successRate * 100), color: metrics.successRate >= 0.9 ? .green : .orange)
        PerformanceRow(title: "Avg Time", value: String(format: "%.2fms", metrics.averageProcessingTimeMs), color: metrics.averageProcessingTimeMs <= 10.0 ? .green : .orange)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .clipShape(RoundedRectangle(cornerRadius: 12))
  }
}

struct PerformanceRow: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)
      Text(value)
        .font(.subheadline)
        .fontWeight(.medium)
        .foregroundStyle(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

// MARK: - Alert Configuration View

struct AlertConfigurationView: View {
  let monitoringService: DefaultCoordinateTransformationMonitoringService
  @State private var alertConfig: AlertConfig
  @Environment(\.dismiss) private var dismiss

  init(monitoringService: DefaultCoordinateTransformationMonitoringService) {
    self.monitoringService = monitoringService
    self._alertConfig = State(initialValue: AlertConfig())
  }

  var body: some View {
    NavigationStack {
      Form {
        Section("Success Rate Threshold") {
          HStack {
            Text("Minimum Success Rate")
            Spacer()
            Text("\(Int(alertConfig.minimumSuccessRate * 100))%")
          }
          Slider(value: $alertConfig.minimumSuccessRate, in: 0.5 ... 1.0, step: 0.05)
        }

        Section("Processing Time Threshold") {
          HStack {
            Text("Maximum Processing Time")
            Spacer()
            Text("\(String(format: "%.1f", alertConfig.maximumProcessingTimeMs))ms")
          }
          Slider(value: $alertConfig.maximumProcessingTimeMs, in: 1.0 ... 50.0, step: 0.5)
        }

        Section("Confidence Threshold") {
          HStack {
            Text("Minimum Confidence")
            Spacer()
            Text("\(String(format: "%.2f", alertConfig.minimumConfidence))")
          }
          Slider(value: $alertConfig.minimumConfidence, in: 0.5 ... 1.0, step: 0.05)
        }

        Section("Alert Cooldown") {
          HStack {
            Text("Cooldown Period")
            Spacer()
            Text("\(Int(alertConfig.alertCooldownSeconds / 60)) minutes")
          }
          Slider(value: $alertConfig.alertCooldownSeconds, in: 60 ... 3600, step: 60)
        }
      }
      .navigationTitle("Alert Configuration")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            monitoringService.updateAlertConfig(alertConfig)
            dismiss()
          }
        }
      }
    }
  }
}

// MARK: - Export Data View

struct ExportDataView: View {
  let monitoringService: DefaultCoordinateTransformationMonitoringService
  let timeRange: TimeRange
  @Environment(\.dismiss) private var dismiss
  @State private var exportData: Data?
  @State private var isExporting = false

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        Text("Export Monitoring Data")
          .font(.headline)

        Text("Time Range: \(timeRange.startDate, style: .date) to \(timeRange.endDate, style: .date)")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        if let data = exportData {
          Text("Data Size: \(ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file))")
            .font(.caption)
        }

        if isExporting {
          ProgressView("Exporting data...")
        } else {
          Button("Export Data") {
            Task {
              await exportMonitoringData()
            }
          }
          .buttonStyle(.borderedProminent)
        }

        Spacer()
      }
      .padding()
      .navigationTitle("Export Data")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
      }
      .onAppear {
        Task {
          await exportMonitoringData()
        }
      }
    }
  }

  private func exportMonitoringData() async {
    isExporting = true
    defer { isExporting = false }

    exportData = monitoringService.exportMonitoringData(timeRange: timeRange)
  }
}

#Preview {
  CoordinateTransformationDashboard()
}
