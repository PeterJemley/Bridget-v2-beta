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
    if errorCount > 0 { return .red }
    else if validationRate < 0.95 { return .orange }
    else { return .green }
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
  let statisticalMetrics: StatisticalTrainingMetrics?  // Phase 3 enhancement

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
  @State private var autoRefreshTimer: Timer?

  enum TimeRange: String, CaseIterable {
    case lastHour = "Last Hour"
    case last24Hours = "Last 24 Hours"
    case lastWeek = "Last Week"
    case allTime = "All Time"
  }

  var body: some View {
    ScrollView {
      VStack(spacing: 20) {
        // Header with controls
        headerSection

        if isLoading {
          ProgressView("Loading metrics...")
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let data = metricsData {
          metricsOverviewSection(data: data)
          stagePerformanceChart(data: data)
          memoryUsageChart(data: data)
          stageDetailsSection(data: data)

          if let customResults = data.customValidationResults, !customResults.isEmpty {
            customValidationSection(results: customResults)
          }

          if let statisticalMetrics = data.statisticalMetrics {
            StatisticalUncertaintySection(metrics: statisticalMetrics)
          }
        } else {
          noDataView
        }
      }
      .padding()
    }
    .refreshable { refreshMetrics() }
    .onAppear {
      loadMetrics()
      if autoRefresh { startAutoRefresh() }
    }
    .onDisappear { stopAutoRefresh() }
    .onChange(of: autoRefresh) { _, isOn in
      if isOn { startAutoRefresh() } else { stopAutoRefresh() }
    }
    // Navigation title provided by parent NavigationStack in Settings.
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

          let avgSuccess = data.validationRates.isEmpty
            ? 1.0
            : data.validationRates.values.reduce(0, +) / Double(data.validationRates.count)
          MetricCard(title: "Success Rate",
                     value: "\(String(format: "%.1f", avgSuccess * 100))%",
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

      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12)
      {
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

    let possiblePaths = [
      "metrics/enhanced_pipeline_metrics.json",
      "Documents/metrics/enhanced_pipeline_metrics.json",
      "/tmp/bridget_metrics.json",
    ]

    for path in possiblePaths {
      let url = URL(fileURLWithPath: path)
      if let data = try? Data(contentsOf: url),
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

    DispatchQueue.main.async {
      self.metricsData = self.createSampleData()
      self.isLoading = false
    }
  }

  private func refreshMetrics() { loadMetrics() }

  private func startAutoRefresh() {
    stopAutoRefresh()
    autoRefreshTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { _ in
      if autoRefresh { loadMetrics() }
    }
  }

  private func stopAutoRefresh() {
    autoRefreshTimer?.invalidate()
    autoRefreshTimer = nil
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
                        ],
                        statisticalMetrics: createSampleStatisticalMetrics())
  }

  private func createSampleStatisticalMetrics() -> StatisticalTrainingMetrics {
    StatisticalTrainingMetrics(trainingLossStats: ETASummary(mean: 0.085,
                                                             variance: 0.002,
                                                             min: 0.082,
                                                             max: 0.089),
                               validationLossStats: ETASummary(mean: 0.092,
                                                               variance: 0.003,
                                                               min: 0.088,
                                                               max: 0.096),
                               predictionAccuracyStats: ETASummary(mean: 0.87,
                                                                   variance: 0.001,
                                                                   min: 0.86,
                                                                   max: 0.88),
                               etaPredictionVariance: ETASummary(mean: 120.5,
                                                                 variance: 25.2,
                                                                 min: 95.0,
                                                                 max: 145.0),
                               performanceConfidenceIntervals: PerformanceConfidenceIntervals(accuracy95CI: ConfidenceInterval(lower: 0.84, upper: 0.90),
                                                                                              f1Score95CI: ConfidenceInterval(lower: 0.82, upper: 0.92),
                                                                                              meanError95CI: ConfidenceInterval(lower: 0.08, upper: 0.16)),
                               errorDistribution: ErrorDistributionMetrics(absoluteErrorStats: ETASummary(mean: 0.045,
                                                                                                          variance: 0.002,
                                                                                                          min: 0.025,
                                                                                                          max: 0.065),
                                                                           relativeErrorStats: ETASummary(mean: 0.12,
                                                                                                          variance: 0.005,
                                                                                                          min: 0.08,
                                                                                                          max: 0.16),
                                                                           withinOneStdDev: 68.5,
                                                                           withinTwoStdDev: 95.2))
  }
}

// Supporting views (StageMetricCard, StageDetailRow, StatisticalUncertaintySection).

// MARK: - StageMetricCard

private struct StageMetricCard: View {
  let metric: PipelineStageMetric

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Circle()
          .fill(metric.statusColor)
          .frame(width: 8, height: 8)
        Text(metric.displayName)
          .font(.subheadline)
          .fontWeight(.semibold)
        Spacer()
      }

      HStack(spacing: 12) {
        Label("\(String(format: "%.1f", metric.duration))s", systemImage: "timer")
          .font(.caption)
          .foregroundColor(.secondary)
        Label("\(metric.memory) MB", systemImage: "memorychip")
          .font(.caption)
          .foregroundColor(.secondary)
        Label("\(Int(metric.validationRate * 100))%", systemImage: "checkmark.seal")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      ProgressView(value: max(0, min(1, metric.validationRate))) {
        Text("Validation")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      .tint(metric.statusColor)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.systemBackground))
    .cornerRadius(10)
    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
  }
}

// MARK: - StageDetailRow

private struct StageDetailRow: View {
  let metric: PipelineStageMetric

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(metric.displayName)
          .font(.subheadline)
          .fontWeight(.semibold)
        Spacer()
        statusBadge
      }

      HStack(spacing: 12) {
        infoChip(icon: "timer", text: "\(String(format: "%.1f", metric.duration))s")
        infoChip(icon: "memorychip", text: "\(metric.memory) MB")
        infoChip(icon: "exclamationmark.triangle", text: "\(metric.errorCount) errors",
                 color: metric.errorCount > 0 ? .red.opacity(0.15) : Color.gray.opacity(0.12),
                 foreground: metric.errorCount > 0 ? .red : .secondary)
        infoChip(icon: "person.3", text: "\(metric.recordCount) records")
        infoChip(icon: "checkmark.seal", text: "\(Int(metric.validationRate * 100))%")
      }
    }
    .padding()
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
  }

  private var statusBadge: some View {
    Text(metric.errorCount > 0 ? "Issues" : (metric.validationRate < 0.95 ? "Warning" : "OK"))
      .font(.caption2)
      .fontWeight(.semibold)
      .foregroundColor(metric.statusColor)
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(metric.statusColor.opacity(0.12))
      .cornerRadius(6)
  }

  private func infoChip(icon: String,
                        text: String,
                        color: Color = Color.gray.opacity(0.12),
                        foreground: Color = .secondary) -> some View
  {
    HStack(spacing: 6) {
      Image(systemName: icon)
      Text(text)
    }
    .font(.caption)
    .foregroundColor(foreground)
    .padding(.horizontal, 8)
    .padding(.vertical, 6)
    .background(color)
    .cornerRadius(6)
  }
}

// MARK: - Statistical Uncertainty Section (added)

struct StatisticalUncertaintySection: View {
  let metrics: StatisticalTrainingMetrics

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Model Uncertainty & Statistical Metrics")
        .font(.headline)

      // Top summary cards
      LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 12)
      {
        StatMiniCard(title: "Accuracy 95% CI",
                     value: "\(percent(metrics.performanceConfidenceIntervals.accuracy95CI.lower))–\(percent(metrics.performanceConfidenceIntervals.accuracy95CI.upper))",
                     color: .green)

        StatMiniCard(title: "F1 95% CI",
                     value: "\(percent(metrics.performanceConfidenceIntervals.f1Score95CI.lower))–\(percent(metrics.performanceConfidenceIntervals.f1Score95CI.upper))",
                     color: .blue)

        StatMiniCard(title: "Mean Error 95% CI",
                     value: "\(String(format: "%.3f", metrics.performanceConfidenceIntervals.meanError95CI.lower))–\(String(format: "%.3f", metrics.performanceConfidenceIntervals.meanError95CI.upper))",
                     color: .orange)
      }

      // Loss stats
      VStack(alignment: .leading, spacing: 8) {
        Text("Loss Statistics")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        HStack(spacing: 16) {
          StatValueRow(label: "Training Loss",
                       mean: metrics.trainingLossStats.mean,
                       stdDev: metrics.trainingLossStats.stdDev,
                       range: (metrics.trainingLossStats.min, metrics.trainingLossStats.max),
                       color: .teal)
          StatValueRow(label: "Validation Loss",
                       mean: metrics.validationLossStats.mean,
                       stdDev: metrics.validationLossStats.stdDev,
                       range: (metrics.validationLossStats.min, metrics.validationLossStats.max),
                       color: .purple)
        }
      }

      // Error distribution quick chart
      VStack(alignment: .leading, spacing: 8) {
        Text("Prediction Error Distribution")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        Chart {
          BarMark(x: .value("Within σ", "≤1σ"),
                  y: .value("Percent", metrics.errorDistribution.withinOneStdDev))
            .foregroundStyle(.mint.gradient)
          BarMark(x: .value("Within σ", "≤2σ"),
                  y: .value("Percent", metrics.errorDistribution.withinTwoStdDev))
            .foregroundStyle(.cyan.gradient)
        }
        .chartYAxisLabel("Percent", position: .leading)
        .frame(height: 140)
      }

      // Prediction accuracy and variance
      VStack(alignment: .leading, spacing: 8) {
        Text("Prediction Accuracy & Variance")
          .font(.subheadline)
          .foregroundStyle(.secondary)

        HStack(spacing: 16) {
          StatMiniCard(title: "Accuracy Mean",
                       value: percent(metrics.predictionAccuracyStats.mean),
                       color: .green)
          StatMiniCard(title: "Accuracy ±σ",
                       value: "±\(percent(metrics.predictionAccuracyStats.stdDev))",
                       color: .green.opacity(0.8))
          StatMiniCard(title: "ETA Var (σ)",
                       value: String(format: "%.1f", metrics.etaPredictionVariance.stdDev),
                       color: .indigo)
        }
      }
    }
    .padding()
    .background(Color(.systemBackground))
    .cornerRadius(12)
    .shadow(radius: 2)
  }

  private func percent(_ value: Double) -> String {
    "\(String(format: "%.1f", value * 100))%"
  }
}

private struct StatMiniCard: View {
  let title: String
  let value: String
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(title)
        .font(.caption)
        .foregroundColor(.secondary)
      Text(value)
        .font(.headline)
        .foregroundStyle(color)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
  }
}

private struct StatValueRow: View {
  let label: String
  let mean: Double
  let stdDev: Double
  let range: (min: Double, max: Double)
  let color: Color

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(label)
        .font(.caption)
        .foregroundColor(.secondary)
      Text("Mean \(String(format: "%.3f", mean))  •  σ \(String(format: "%.3f", stdDev))")
        .font(.subheadline)
        .foregroundStyle(color)
      Text("Range \(String(format: "%.3f", range.min)) – \(String(format: "%.3f", range.max))")
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color(.secondarySystemBackground))
    .cornerRadius(10)
  }
}

#Preview {
  PipelineMetricsDashboard()
}
