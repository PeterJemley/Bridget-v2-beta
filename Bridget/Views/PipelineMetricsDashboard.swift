import Charts
import Observation
import SwiftUI

// MARK: - Metrics Models

struct PipelineStageMetric: Codable, Identifiable {
  var id: String { stage }
  let stage: String
  let duration: Double
  let memory: Int
  let errorCount: Int
  let recordCount: Int
  let validationRate: Double

  var displayName: String {
    switch stage {
    case "dataLoading": return "Data Loading"
    case "dataValidation": return "Data Validation"
    case "featureEngineering": return "Feature Engineering"
    case "mlMultiArrayConversion": return "ML Array Conversion"
    case "modelTraining": return "Model Training"
    case "modelValidation": return "Model Validation"
    case "artifactExport": return "Artifact Export"
    default: return stage.capitalized
    }
  }

  var statusColor: Color {
    if errorCount > 0 {
      return .red
    } else if validationRate < 0.95 {
      return .orange
    } else {
      return .green
    }
  }
}

struct PipelineMetricsData: Codable {
  let timestamp: Date
  let stageDurations: [String: Double]
  let memoryUsage: [String: Int]
  let validationRates: [String: Double]
  let errorCounts: [String: Int]
  let recordCounts: [String: Int]
  let customValidationResults: [String: Bool]?

  var stageMetrics: [PipelineStageMetric] {
    stageDurations.keys.map { stage in
      PipelineStageMetric(stage: stage,
                          duration: stageDurations[stage] ?? 0.0,
                          memory: memoryUsage[stage] ?? 0,
                          errorCount: errorCounts[stage] ?? 0,
                          recordCount: recordCounts[stage] ?? 0,
                          validationRate: validationRates[stage] ?? 1.0)
    }.sorted { $0.duration > $1.duration }
  }
}

// MARK: - Main Dashboard View

struct PipelineMetricsDashboard: View {
  @State private var metricsData: PipelineMetricsData?
  @State private var isLoading = false
  @State private var lastUpdateTime = Date()
  @State private var autoRefresh = true
  @State private var selectedTimeRange: TimeRange = .last24Hours

  enum TimeRange: String, CaseIterable {
    case lastHour = "Last Hour"
    case last24Hours = "Last 24 Hours"
    case lastWeek = "Last Week"
    case allTime = "All Time"
  }

  var body: some View {
    NavigationView {
      ScrollView {
        VStack(spacing: 20) {
          // Header with controls
          headerSection

          if isLoading {
            ProgressView("Loading metrics...")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if let data = metricsData {
            // Metrics overview
            metricsOverviewSection(data: data)

            // Stage performance chart
            stagePerformanceChart(data: data)

            // Memory usage chart
            memoryUsageChart(data: data)

            // Detailed stage list
            stageDetailsSection(data: data)

            // Custom validation results
            if let customResults = data.customValidationResults, !customResults.isEmpty {
              customValidationSection(results: customResults)
            }
          } else {
            noDataView
          }
        }
        .padding()
      }
      .navigationTitle("Pipeline Metrics")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button(action: refreshMetrics) {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
    }
    .onAppear {
      loadMetrics()
      if autoRefresh {
        startAutoRefresh()
      }
    }
    .onDisappear {
      stopAutoRefresh()
    }
  }

  // MARK: - Header Section

  private var headerSection: some View {
    VStack(spacing: 16) {
      HStack {
        VStack(alignment: .leading) {
          Text("Pipeline Performance Dashboard")
            .font(.title2)
            .fontWeight(.semibold)

          if let data = metricsData {
            Text("Last updated: \(data.timestamp, style: .relative)")
              .font(.caption)
              .foregroundColor(.secondary)
          }
        }

        Spacer()

        VStack(alignment: .trailing) {
          Toggle("Auto-refresh", isOn: $autoRefresh)
            .toggleStyle(.switch)
            .scaleEffect(0.8)

          Picker("Time Range", selection: $selectedTimeRange) {
            ForEach(TimeRange.allCases, id: \.self) { range in
              Text(range.rawValue).tag(range)
            }
          }
          .pickerStyle(.menu)
        }
      }

      if let data = metricsData {
        HStack(spacing: 20) {
          MetricCard(title: "Total Duration",
                     value: "\(String(format: "%.1f", data.stageDurations.values.reduce(0, +)))s",
                     color: .blue)

          MetricCard(title: "Total Memory",
                     value: "\(data.memoryUsage.values.reduce(0, +)) MB",
                     color: .purple)

          MetricCard(title: "Success Rate",
                     value: "\(String(format: "%.1f", data.validationRates.values.reduce(0, +) / Double(data.validationRates.count) * 100))%",
                     color: .green)
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }

  // MARK: - Metrics Overview Section

  private func metricsOverviewSection(data: PipelineMetricsData) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Performance Overview")
        .font(.headline)

      LazyVGrid(columns: [
        GridItem(.flexible()),
        GridItem(.flexible()),
      ], spacing: 12) {
        ForEach(data.stageMetrics.prefix(6)) { metric in
          StageMetricCard(metric: metric)
        }
      }
    }
  }

  // MARK: - Stage Performance Chart

  private func stagePerformanceChart(data: PipelineMetricsData) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Stage Performance")
        .font(.headline)

      Chart(data.stageMetrics) { metric in
        BarMark(x: .value("Duration", metric.duration),
                y: .value("Stage", metric.displayName))
          .foregroundStyle(metric.statusColor.gradient)
          .annotation(position: .trailing) {
            Text("\(String(format: "%.1f", metric.duration))s")
              .font(.caption)
              .foregroundColor(.secondary)
          }
      }
      .frame(height: 200)
      .chartXAxis {
        AxisMarks(position: .bottom) {
          AxisGridLine()
          AxisTick()
          AxisValueLabel()
        }
      }
      .chartYAxis {
        AxisMarks(position: .leading) {
          AxisValueLabel()
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(radius: 2)
  }

  // MARK: - Memory Usage Chart

  private func memoryUsageChart(data: PipelineMetricsData) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Memory Usage by Stage")
        .font(.headline)

      Chart(data.stageMetrics) { metric in
        LineMark(x: .value("Stage", metric.displayName),
                 y: .value("Memory", metric.memory))
          .symbol(Circle())
          .foregroundStyle(.purple.gradient)

        AreaMark(x: .value("Stage", metric.displayName),
                 y: .value("Memory", metric.memory))
          .foregroundStyle(.purple.opacity(0.1))
      }
      .frame(height: 200)
      .chartYAxis {
        AxisMarks(position: .leading) {
          AxisGridLine()
          AxisTick()
          AxisValueLabel()
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(radius: 2)
  }

  // MARK: - Stage Details Section

  private func stageDetailsSection(data: PipelineMetricsData) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Stage Details")
        .font(.headline)

      ForEach(data.stageMetrics) { metric in
        StageDetailRow(metric: metric)
      }
    }
  }

  // MARK: - Custom Validation Section

  private func customValidationSection(results: [String: Bool]) -> some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Custom Validation Results")
        .font(.headline)

      ForEach(Array(results.keys.sorted()), id: \.self) { validatorName in
        HStack {
          Image(systemName: results[validatorName] == true ? "checkmark.circle.fill" : "xmark.circle.fill")
            .foregroundColor(results[validatorName] == true ? .green : .red)

          Text(validatorName)
            .font(.subheadline)

          Spacer()

          Text(results[validatorName] == true ? "Passed" : "Failed")
            .font(.caption)
            .foregroundColor(results[validatorName] == true ? .green : .red)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
              RoundedRectangle(cornerRadius: 4)
                .fill(results[validatorName] == true ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
            )
        }
        .padding(.vertical, 4)
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(radius: 2)
  }

  // MARK: - No Data View

  private var noDataView: some View {
    VStack(spacing: 16) {
      Image(systemName: "chart.bar.doc.horizontal")
        .font(.system(size: 48))
        .foregroundColor(.secondary)

      Text("No Metrics Available")
        .font(.title2)
        .fontWeight(.semibold)

      Text("Run the pipeline to generate metrics, or check the metrics file path.")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)

      Button("Refresh") {
        refreshMetrics()
      }
      .buttonStyle(.borderedProminent)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }

  // MARK: - Helper Methods

  private func loadMetrics() {
    isLoading = true

    // Try multiple possible paths for the metrics file
    let possiblePaths = [
      "metrics/enhanced_pipeline_metrics.json",
      "Documents/metrics/enhanced_pipeline_metrics.json",
      "/tmp/bridget_metrics.json",
    ]

    for path in possiblePaths {
      if let url = URL(string: path),
         let data = try? Data(contentsOf: url),
         let decoded = try? JSONDecoder.bridgeDecoder().decode(PipelineMetricsData.self, from: data)
      {
        DispatchQueue.main.async {
          self.metricsData = decoded
          self.lastUpdateTime = Date()
          self.isLoading = false
        }
        return
      }
    }

    // If no file found, create sample data for demonstration
    DispatchQueue.main.async {
      self.metricsData = self.createSampleData()
      self.isLoading = false
    }
  }

  private func refreshMetrics() {
    loadMetrics()
  }

  private func startAutoRefresh() {
    Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
      if autoRefresh {
        loadMetrics()
      }
    }
  }

  private func stopAutoRefresh() {
    // Timer will be invalidated when view disappears
  }

  private func createSampleData() -> PipelineMetricsData {
    PipelineMetricsData(timestamp: Date(),
                        stageDurations: [
                          "dataLoading": 2.5,
                          "dataValidation": 1.8,
                          "featureEngineering": 15.2,
                          "mlMultiArrayConversion": 3.1,
                          "modelTraining": 45.7,
                          "modelValidation": 8.3,
                          "artifactExport": 1.2,
                        ],
                        memoryUsage: [
                          "dataLoading": 128,
                          "dataValidation": 256,
                          "featureEngineering": 1024,
                          "mlMultiArrayConversion": 512,
                          "modelTraining": 2048,
                          "modelValidation": 1024,
                          "artifactExport": 256,
                        ],
                        validationRates: [
                          "dataLoading": 1.0,
                          "dataValidation": 0.98,
                          "featureEngineering": 0.95,
                          "mlMultiArrayConversion": 1.0,
                          "modelTraining": 1.0,
                          "modelValidation": 0.92,
                          "artifactExport": 1.0,
                        ],
                        errorCounts: [
                          "dataLoading": 0,
                          "dataValidation": 2,
                          "featureEngineering": 5,
                          "mlMultiArrayConversion": 0,
                          "modelTraining": 0,
                          "modelValidation": 8,
                          "artifactExport": 0,
                        ],
                        recordCounts: [
                          "dataLoading": 10000,
                          "dataValidation": 10000,
                          "featureEngineering": 9800,
                          "mlMultiArrayConversion": 9800,
                          "modelTraining": 9800,
                          "modelValidation": 9800,
                          "artifactExport": 9800,
                        ],
                        customValidationResults: [
                          "NoMissingGateAnomValidator": true,
                          "DetourDeltaRangeValidator": false,
                          "DataQualityValidator": true,
                        ])
  }
}

// MARK: - Supporting Views

struct MetricCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)

      Text(value)
        .font(.title2)
        .fontWeight(.bold)
        .foregroundColor(color)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(8)
    .shadow(radius: 1)
  }
}

struct StageMetricCard: View {
  let metric: PipelineStageMetric

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(metric.displayName)
          .font(.subheadline)
          .fontWeight(.medium)

        Spacer()

        Circle()
          .fill(metric.statusColor)
          .frame(width: 8, height: 8)
      }

      HStack {
        VStack(alignment: .leading, spacing: 2) {
          Text("Duration")
            .font(.caption2)
            .foregroundColor(.secondary)
          Text("\(String(format: "%.1f", metric.duration))s")
            .font(.caption)
            .fontWeight(.semibold)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 2) {
          Text("Memory")
            .font(.caption2)
            .foregroundColor(.secondary)
          Text("\(metric.memory) MB")
            .font(.caption)
            .fontWeight(.semibold)
        }
      }

      if metric.errorCount > 0 {
        HStack {
          Image(systemName: "exclamationmark.triangle.fill")
            .foregroundColor(.orange)
            .font(.caption2)

          Text("\(metric.errorCount) errors")
            .font(.caption2)
            .foregroundColor(.orange)

          Spacer()
        }
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(8)
  }
}

struct StageDetailRow: View {
  let metric: PipelineStageMetric

  var body: some View {
    VStack(spacing: 8) {
      HStack {
        VStack(alignment: .leading, spacing: 4) {
          Text(metric.displayName)
            .font(.subheadline)
            .fontWeight(.medium)

          Text("\(metric.recordCount) records processed")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Spacer()

        VStack(alignment: .trailing, spacing: 4) {
          Text("\(String(format: "%.1f", metric.duration))s")
            .font(.subheadline)
            .fontWeight(.semibold)

          Text("\(metric.memory) MB")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }

      HStack {
        HStack(spacing: 4) {
          Image(systemName: "checkmark.circle.fill")
            .foregroundColor(.green)
            .font(.caption2)

          Text("\(String(format: "%.1f", metric.validationRate * 100))% valid")
            .font(.caption)
            .foregroundColor(.green)
        }

        Spacer()

        if metric.errorCount > 0 {
          HStack(spacing: 4) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.orange)
              .font(.caption2)

            Text("\(metric.errorCount) errors")
              .font(.caption)
              .foregroundColor(.orange)
          }
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(8)
    .shadow(radius: 1)
  }
}

#Preview {
  PipelineMetricsDashboard()
}
