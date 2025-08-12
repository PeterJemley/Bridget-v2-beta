//
//  MLPipelineSettingsView.swift (fixed)
//  Bridget
//
//  Purpose: Integrated settings & management interface for the ML Training Data Pipeline
//  Notes:
//  - Uses NavigationStack (iOS 16+), @AppStorage for settings, and safer paths.
//  - Shows a ShareLink for the last export, which helps on real devices.
//  - Hides "Downloads" on iOS (keeps on macOS).
//

import OSLog
import SwiftData
import SwiftUI

public struct MLPipelineSettingsView: View {
  @Environment(\.modelContext) private var modelContext
  @Environment(\.dismiss) private var dismiss

  // Persisted settings
  @AppStorage("MLExportDestination") private var exportDestination: String = "Documents"
  @AppStorage("MLAutoExportEnabled") private var autoExportEnabled: Bool = false
  @AppStorage("MLAutoExportTime") private var autoExportTime: String = "01:00" // "HH:mm"
  @AppStorage("MLLastExportDate") private var lastExportDate: Double = 0 // timeIntervalSince1970

  // UI state
  @State private var isExporting = false
  @State private var exportProgress: Double = 0
  @State private var exportStatus: String = ""
  @State private var showingExportSheet = false
  @State private var selectedDate = Date()
  @State private var lastExportURL: URL?
  @State private var showingTimePicker = false
  @State private var tempTime = Date()

  // MARK: - Live pipeline status state (updated from MLPipelineBackgroundManager)

  @State private var dataAvailableToday: Bool = false
  @State private var dataAvailableLastWeek: Bool = false
  @State private var historicalDataComplete: Bool = false
  @State private var lastPopulationDate: Date?
  @State private var lastExportDateLive: Date?
  @State private var lastBackgroundTaskRun: Date?
  @State private var lastBackgroundTaskError: String?

  private let logger = Logger(subsystem: "Bridget", category: "MLPipeline")

  // MARK: - Computed

  private var destinationOptions: [String] {
    #if os(iOS)
      return ["Documents"]
    #else
      return ["Documents", "Downloads"]
    #endif
  }

  /// Compose a pipeline data availability summary string based on live status.
  private var dataAvailabilityText: String {
    let todayStatus = dataAvailableToday ? "Available" : "Unavailable"
    let lastWeekStatus = dataAvailableLastWeek ? "Available" : "Unavailable"
    let historicalStatus = historicalDataComplete ? "Complete" : "Partial"

    return "Today: \(todayStatus) • Last Week: \(lastWeekStatus) • Historical: \(historicalStatus)"
  }

  /// Icon reflects overall data availability: green check if all good, yellow exclamation if partial, red x if major missing.
  private var dataAvailabilityIcon: String {
    if dataAvailableToday && dataAvailableLastWeek && historicalDataComplete {
      return "checkmark.circle.fill"
    } else if dataAvailableToday || dataAvailableLastWeek || historicalDataComplete {
      return "exclamationmark.triangle.fill"
    } else {
      return "xmark.octagon.fill"
    }
  }

  /// Color representing data availability status.
  private var dataAvailabilityColor: Color {
    if dataAvailableToday && dataAvailableLastWeek && historicalDataComplete {
      return .green
    } else if dataAvailableToday || dataAvailableLastWeek || historicalDataComplete {
      return .yellow
    } else {
      return .red
    }
  }

  /// Last export display string from live status or fallback.
  private var lastExportText: String {
    if let lastExportDateLive = lastExportDateLive {
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      return formatter.string(from: lastExportDateLive)
    } else if lastExportDate > 0 {
      let date = Date(timeIntervalSince1970: lastExportDate)
      let formatter = DateFormatter()
      formatter.dateStyle = .medium
      formatter.timeStyle = .short
      return formatter.string(from: date)
    } else {
      return "Never"
    }
  }

  // MARK: - View

  public var body: some View {
    NavigationStack {
      List {
        // Pipeline Status
        Section("Pipeline Status") {
          PipelineStatusRow(title: "Data Availability",
                            subtitle: dataAvailabilityText,
                            icon: dataAvailabilityIcon,
                            color: dataAvailabilityColor)

          if let lastPopDate = lastPopulationDate {
            PipelineStatusRow(title: "Last Data Population",
                              subtitle: DateFormatter.localizedString(from: lastPopDate, dateStyle: .medium, timeStyle: .short),
                              icon: "tray.and.arrow.down.fill",
                              color: .secondary)
          } else {
            PipelineStatusRow(title: "Last Data Population",
                              subtitle: "Unknown",
                              icon: "tray.and.arrow.down.fill",
                              color: .secondary)
          }

          PipelineStatusRow(title: "Last Export",
                            subtitle: lastExportText,
                            icon: "doc.text",
                            color: .blue)

          PipelineStatusRow(title: "Export Destination",
                            subtitle: exportDestination,
                            icon: "folder",
                            color: .green)
        }

        // Data Management
        Section("Data Management") {
          Button(action: populateTodayData) {
            Label("Populate Today's Data", systemImage: "calendar.badge.plus")
          }
          .disabled(isExporting)

          Button(action: populateLastWeekData) {
            Label("Populate Last Week's Data", systemImage: "calendar.badge.clock")
          }
          .disabled(isExporting)

          Button(action: populateHistoricalData) {
            Label("Populate Historical Data",
                  systemImage: "calendar.badge.exclamationmark")
          }
          .disabled(isExporting)
        }

        // Export Operations
        Section("Export Operations") {
          Button(action: { showingExportSheet = true }) {
            Label("Export Day as NDJSON",
                  systemImage: "square.and.arrow.up")
          }
          .disabled(isExporting)

          if isExporting {
            VStack(alignment: .leading, spacing: 8) {
              Text("Exporting…").font(.headline)
              Text(exportStatus)
                .font(.caption)
                .foregroundStyle(.secondary)
              ProgressView(value: exportProgress)
                .progressViewStyle(.linear)
            }
            .padding(.vertical, 6)
          }

          if let url = lastExportURL {
            // Fix: pass url value, not binding, to ShareLink (already done)
            ShareLink(item: url) {
              Label("Share Last Export",
                    systemImage: "square.and.arrow.up.on.square")
            }
          }
        }

        // Automation
        Section("Automation") {
          Toggle("Enable Daily Auto-Export", isOn: $autoExportEnabled)
            .onChange(of: autoExportEnabled) { _, _ in
              updateAutoExportSchedule()
            }

          if autoExportEnabled {
            HStack {
              Text("Export Time")
              Spacer()
              Text(autoExportTime).foregroundStyle(.secondary) // Fix: Text shows value, not binding
            }
            .contentShape(Rectangle())
            .onTapGesture { prepareTimePicker() }
          }
        }

        // Information
        Section("Information") {
          NavigationLink("Export History") {
            ExportHistoryView()
          }
          NavigationLink("Pipeline Documentation") {
            PipelineDocumentationView()
          }
          NavigationLink("Troubleshooting") {
            PipelineTroubleshootingView(lastBackgroundTaskRun: lastBackgroundTaskRun,
                                        lastBackgroundTaskError: lastBackgroundTaskError,
                                        onRerunHealthChecks: performHealthCheck)
          }
        }
      }
      .navigationTitle("ML Pipeline")
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .topBarLeading) {
          Button(action: refreshStatus) {
            Image(systemName: "arrow.clockwise")
          }
        }
      }
    }
    .sheet(isPresented: $showingExportSheet) {
      ExportConfigurationSheet(selectedDate: $selectedDate,
                               exportDestination: $exportDestination,
                               destinations: destinationOptions,
                               onExport: performExport)
    }
    .sheet(isPresented: $showingTimePicker) {
      NavigationStack {
        VStack(spacing: 16) {
          DatePicker("Time", selection: $tempTime, displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .labelsHidden()
            .padding(.vertical, 12)

          Button("Save") {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            autoExportTime = formatter.string(from: tempTime)
            showingTimePicker = false
            updateAutoExportSchedule()
          }
          .buttonStyle(.borderedProminent)
        }
        .padding()
        .navigationTitle("Auto-Export Time")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            Button("Cancel") { showingTimePicker = false }
          }
        }
      }
      .presentationDetents([.fraction(0.4)])
    }
    .onAppear(perform: refreshStatus)
  }

  // MARK: - Actions

  private func prepareTimePicker() {
    // Parse autoExportTime "HH:mm" -> Date
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    tempTime = formatter.date(from: autoExportTime)
      ?? Calendar.current.date(bySettingHour: 1, minute: 0, second: 0, of: Date())!
    showingTimePicker = true
  }

  private func populateTodayData() {
    Task {
      do {
        let service = ProbeTickDataService(context: modelContext)
        try await service.populateTodayProbeTicks()
        await MainActor.run {
          logger.info("Successfully populated today's ProbeTick data")
          refreshStatus()
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Data Population Success",
          //   subtitle: "Today's data populated successfully.")
        }
      } catch {
        await MainActor.run {
          logger.error("Failed to populate today's data: \(error.localizedDescription)")
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Data Population Failed",
          //   subtitle: "Today's data population failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func populateLastWeekData() {
    Task {
      do {
        let service = ProbeTickDataService(context: modelContext)
        try await service.populateLastWeekProbeTicks()
        await MainActor.run {
          logger.info("Successfully populated last week's ProbeTick data")
          refreshStatus()
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Data Population Success",
          //   subtitle: "Last week's data populated successfully.")
        }
      } catch {
        await MainActor.run {
          logger.error("Failed to populate last week's data: \(error.localizedDescription)")
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Data Population Failed",
          //   subtitle: "Last week's data population failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func populateHistoricalData() {
    Task {
      do {
        let service = ProbeTickDataService(context: modelContext)
        let startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
        try await service.populateHistoricalProbeTicks(from: startDate, to: Date())
        await MainActor.run {
          logger.info("Successfully populated historical ProbeTick data")
          refreshStatus()
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Data Population Success",
          //   subtitle: "Historical data populated successfully.")
        }
      } catch {
        await MainActor.run {
          logger.error("Failed to populate historical data: \(error.localizedDescription)")
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Data Population Failed",
          //   subtitle: "Historical data population failed: \(error.localizedDescription)")
        }
      }
    }
  }

  private func performExport(for date: Date, to destination: String) {
    Task {
      await MainActor.run {
        isExporting = true
        exportProgress = 0
        exportStatus = "Preparing…"
      }

      do {
        let exporter = BridgeDataExporter(context: modelContext)

        // Determine export path
        let exportPath = getExportPath(for: destination)
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateString = formatter.string(from: date)
        let fileName = "minutes_\(dateString).ndjson"
        let outputURL = exportPath.appendingPathComponent(fileName)

        await MainActor.run {
          exportStatus = "Exporting \(dateString)…"
          exportProgress = 0.4
        }

        try await exporter.exportDailyNDJSON(for: date, to: outputURL)

        await MainActor.run {
          exportStatus = "Export completed"
          exportProgress = 1.0
          lastExportDate = Date().timeIntervalSince1970
          lastExportDateLive = Date()
          lastExportURL = outputURL
          logger.info("Successfully exported data for \(dateString) to \(outputURL.path)")
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Export Success",
          //   subtitle: "Exported data for \(dateString) successfully.")
        }

        // Let the progress bar reach 100% before resetting
        try? await Task.sleep(nanoseconds: 800_000_000)
        await MainActor.run {
          isExporting = false
          exportProgress = 0
          exportStatus = ""
        }
      } catch {
        await MainActor.run {
          exportStatus = "Export failed: \(error.localizedDescription)"
          exportProgress = 0
          logger.error("Export failed: \(error.localizedDescription)")
          // TODO: Implement actual notification call here
          // MLPipelineNotificationManager.shared.showNotification(
          //   title: "Export Failed",
          //   subtitle: "Export failed: \(error.localizedDescription)")
        }
        try? await Task.sleep(nanoseconds: 800_000_000)
        await MainActor.run {
          isExporting = false
          exportStatus = ""
        }
      }
    }
  }

  /// Refresh live status from MLPipelineBackgroundManager to update UI
  private func refreshStatus() {
    // TODO: Replace calls to MLPipelineBackgroundManager.shared with stubbed demo status
    Task {
      // Stubbed demo status
      struct DemoStatus {
        var dataAvailableToday: Bool = true
        var dataAvailableLastWeek: Bool = true
        var historicalDataComplete: Bool = false
        var lastPopulationDate: Date? = Date().addingTimeInterval(-3600)
        var lastExportDate: Date? = Date().addingTimeInterval(-7200)
        var lastBackgroundTaskRun: Date? = Date().addingTimeInterval(-10800)
        var lastBackgroundTaskError: String? = nil
        var healthCheckSummary: String = "All Checks Passed"
      }
      let status = DemoStatus() // TODO: Replace with real async call when available

      await MainActor.run {
        dataAvailableToday = status.dataAvailableToday
        dataAvailableLastWeek = status.dataAvailableLastWeek
        historicalDataComplete = status.historicalDataComplete
        lastPopulationDate = status.lastPopulationDate
        lastExportDateLive = status.lastExportDate
        lastBackgroundTaskRun = status.lastBackgroundTaskRun
        lastBackgroundTaskError = status.lastBackgroundTaskError
      }
    }
  }

  /// Update auto-export schedule in background manager and notification manager
  private func updateAutoExportSchedule() {
    // TODO: Replace with actual scheduling when MLPipelineBackgroundManager is implemented
    Task {
      // await MLPipelineBackgroundManager.shared.scheduleNextExecution(
      //   enabled: autoExportEnabled,
      //   timeHHmm: autoExportTime
      // )
      // await MLPipelineNotificationManager.shared.updateScheduledNotifications()
    }
  }

  /// Perform health checks for troubleshooting view
  private func performHealthCheck() {
    Task {
      // TODO: Replace with actual health check call
      // let bgManager = MLPipelineBackgroundManager.shared
      // await bgManager.runHealthChecks()
      // await refreshStatus()
      await MainActor.run {
        // TODO: Implement actual notification call here
        // MLPipelineNotificationManager.shared.showNotification(
        //   title: "Health Check Complete",
        //   subtitle: "Pipeline health checks have completed.")
      }
    }
  }

  /// Determine export URL path based on destination option
  private func getExportPath(for destination: String) -> URL {
    switch destination {
    case "Documents":
      return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? URL.documentsDirectory()
    case "Downloads":
      #if os(macOS)
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
          ?? URL.documentsDirectory()
      #else
        // iOS: no sandboxed Downloads; fall back to Documents
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
          ?? URL.documentsDirectory()
      #endif
    default:
      return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        ?? URL.documentsDirectory()
    }
  }
}

private extension URL {
  static func documentsDirectory() -> URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
  }
}

// MARK: - Supporting Views

public struct PipelineStatusRow: View {
  let title: String
  let subtitle: String
  let icon: String
  let color: Color

  public var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 2)
  }
}

public struct ExportConfigurationSheet: View {
  @Binding var selectedDate: Date
  @Binding var exportDestination: String
  let destinations: [String]
  let onExport: (Date, String) -> Void

  @Environment(\.dismiss) private var dismiss

  public var body: some View {
    NavigationStack {
      Form {
        Section("Export Configuration") {
          DatePicker("Export Date", selection: $selectedDate, displayedComponents: .date)
          Picker("Export Destination", selection: $exportDestination) {
            // Fix: use only value types in Picker rows (strings), no bindings passed to Text
            ForEach(destinations, id: \.self) { val in
              Text(val).tag(val)
            }
          }
        }

        Section {
          Button("Start Export") {
            onExport(selectedDate, exportDestination)
            dismiss()
          }
          .frame(maxWidth: .infinity)
          .buttonStyle(.borderedProminent)
        }
      }
      .navigationTitle("Export Configuration")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}

// MARK: - ExportHistoryView: Shows list of exported NDJSON files with preview/share

public struct ExportHistoryView: View {
  @State private var exportedFiles: [ExportedFile] = []
  @State private var selectedFileURL: URL?
  @State private var showingFilePreview = false

  private let fileManager = FileManager.default
  private let logger = Logger(subsystem: "Bridget", category: "ExportHistoryView")

  public var body: some View {
    NavigationStack {
      if exportedFiles.isEmpty {
        Text("No export files found.")
          .foregroundStyle(.secondary)
          .padding()
          .navigationTitle("Export History")
      } else {
        List {
          // Fix: ForEach with bindings for exportedFiles to allow .onDelete usage
          ForEach($exportedFiles) { $file in
            Button {
              // Fix: assign new instance of URL to selectedFileURL, do not mutate ExportedFile properties
              selectedFileURL = $file.wrappedValue.url
              showingFilePreview = true
            } label: {
              HStack {
                Image(systemName: "doc.plaintext")
                  .foregroundStyle(.blue)
                  .frame(width: 24)
                VStack(alignment: .leading) {
                  Text($file.wrappedValue.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                  Text($file.wrappedValue.dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.tertiary)
              }
            }
          }
          .onDelete(perform: deleteFiles)
        }
        .navigationTitle("Export History")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            EditButton()
          }
        }
        .sheet(isPresented: $showingFilePreview) {
          if let url = selectedFileURL {
            // Fix: pass selectedFileURL value (URL), not binding, to ShareLink
            ShareLink(item: url) {
              Text("Share \(url.lastPathComponent)")
                .padding()
            }
          }
        }
      }
    }
    .task {
      await loadExportedFiles()
    }
  }

  /// Represents an exported file with metadata to display
  struct ExportedFile: Identifiable {
    let id = UUID()
    let url: URL
    let name: String
    let date: Date

    var dateText: String {
      DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
    }
  }

  /// Load exported NDJSON files from known export directories
  private func loadExportedFiles() async {
    var files: [ExportedFile] = []

    // Gather from both Documents and Downloads (if macOS)
    let documentURLs = [URL.documentsDirectory()]
    #if os(macOS)
      let downloadsURLs = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
    #else
      let downloadsURLs: [URL] = []
    #endif

    let searchURLs = documentURLs + downloadsURLs

    for baseURL in searchURLs {
      do {
        let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        let ndjsonFiles = contents.filter { $0.pathExtension.lowercased() == "ndjson" }

        for fileURL in ndjsonFiles {
          let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
          let modDate = resourceValues.contentModificationDate ?? Date.distantPast
          // Fix: ExportedFile properties are let constants, no mutation here; just create new instance
          let exportedFile = ExportedFile(url: fileURL, name: fileURL.lastPathComponent, date: modDate)
          files.append(exportedFile)
        }
      } catch {
        // Ignore directory errors, log if needed
        logger.error("Failed to list directory \(baseURL.path): \(error.localizedDescription)")
      }
    }

    // Sort files newest first
    files.sort { $0.date > $1.date }

    await MainActor.run {
      exportedFiles = files
    }
  }

  /// Delete files from disk and update list
  private func deleteFiles(at offsets: IndexSet) {
    for index in offsets {
      let file = exportedFiles[index]
      do {
        try fileManager.removeItem(at: file.url)
      } catch {
        logger.error("Failed to delete file \(file.url.path): \(error.localizedDescription)")
      }
    }
    exportedFiles.remove(atOffsets: offsets)
  }
}

// MARK: - PipelineDocumentationView: Static documentation for pipeline

public struct PipelineDocumentationView: View {
  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("ML Pipeline Documentation")
          .font(.largeTitle)
          .bold()

        Text("Overview")
          .font(.title2)
          .bold()
        Text("""
        The ML Training Data Pipeline ingests probe tick data from various sources, organizes it by day, and exports it in NDJSON format for machine learning model training.

        This pipeline provides automated daily exports, manual data population for specific date ranges, and troubleshooting tools to ensure data readiness.

        Key features:
        - Data Availability checks for today, last week, and historical completeness.
        - Export configuration with selectable destination and date.
        - Automation with daily export scheduling and notifications.
        """)

        Text("Export Formats")
          .font(.title2)
          .bold()
        Text("""
        Exports are done in NDJSON (newline-delimited JSON) format. Each line represents a serialized ProbeTick object, suitable for streaming ingestion.

        File naming convention:
        - `minutes_YYYY-MM-DD.ndjson`, where `YYYY-MM-DD` is the export date.

        Exports can be saved either to the Documents or Downloads folder (macOS only).
        """)

        Text("Help and Support")
          .font(.title2)
          .bold()
        Text("""
        For troubleshooting, use the 'Troubleshooting' section to view logs and run health checks.

        If you encounter issues with automated exports, ensure background tasks are enabled and the chosen export time is reasonable.

        Contact support or consult the app documentation for advanced help.
        """)
      }
      .padding()
    }
    .navigationTitle("Documentation")
  }
}

// MARK: - PipelineTroubleshootingView: Diagnostics & health checks

public struct PipelineTroubleshootingView: View {
  let lastBackgroundTaskRun: Date?
  let lastBackgroundTaskError: String?
  let onRerunHealthChecks: () -> Void

  @State private var isRunningCheck = false
  @State private var healthCheckResult: String?

  public var body: some View {
    VStack(spacing: 16) {
      Form {
        Section(header: Text("Last Background Task Run")) {
          if let runDate = lastBackgroundTaskRun {
            Text(DateFormatter.localizedString(from: runDate, dateStyle: .medium, timeStyle: .short))
          } else {
            Text("Never")
              .foregroundStyle(.secondary)
          }
        }

        Section(header: Text("Last Background Task Error")) {
          if let error = lastBackgroundTaskError, !error.isEmpty {
            ScrollView(.horizontal) {
              Text(error)
                .font(.caption)
                .foregroundStyle(.red)
                .lineLimit(3)
                .truncationMode(.tail)
                .padding(4)
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
            }
          } else {
            Text("No recent errors")
              .foregroundStyle(.secondary)
          }
        }

        Section(header: Text("Health Check")) {
          if let result = healthCheckResult {
            Text(result)
              .font(.callout)
              .foregroundStyle(.primary)
              .padding(6)
              .background(Color.green.opacity(0.1))
              .cornerRadius(6)
          } else {
            Text("No health check performed yet.")
              .foregroundStyle(.secondary)
          }

          Button {
            isRunningCheck = true
            healthCheckResult = nil
            Task {
              await runHealthChecks()
              isRunningCheck = false
            }
          } label: {
            if isRunningCheck {
              Label("Running Health Checks…", systemImage: "hourglass")
            } else {
              Label("Run Health Checks", systemImage: "stethoscope")
            }
          }
          .buttonStyle(.borderedProminent)
          .disabled(isRunningCheck)
        }
      }
      .navigationTitle("Troubleshooting")
    }
  }

  private func runHealthChecks() async {
    // TODO: Replace calls to MLPipelineBackgroundManager with stubbed demo behavior
    // await MLPipelineBackgroundManager.shared.runHealthChecks()

    // After running, refresh info with demo data
    // let status = await MLPipelineBackgroundManager.shared.currentStatus()
    struct DemoStatus {
      var healthCheckSummary: String = "All Checks Passed"
    }
    let status = DemoStatus() // TODO: Replace with real async call when available

    await MainActor.run {
      healthCheckResult = status.healthCheckSummary
    }
  }
}

#Preview {
  MLPipelineSettingsView()
    .modelContainer(for: ProbeTick.self, inMemory: true)
}
