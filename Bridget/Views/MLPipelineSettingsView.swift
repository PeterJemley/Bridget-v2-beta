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

    private let logger = Logger(subsystem: "Bridget", category: "MLPipeline")

    // MARK: - Computed

    private var destinationOptions: [String] {
        #if os(iOS)
        return ["Documents"]
        #else
        return ["Documents", "Downloads"]
        #endif
    }

    private var lastExportText: String {
        guard lastExportDate > 0 else { return "Never" }
        let date = Date(timeIntervalSince1970: lastExportDate)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var dataAvailabilityText: String {
        "Today: Available • Last Week: Available • Historical: Partial"
    }
    private var dataAvailabilityIcon: String { "checkmark.circle.fill" }
    private var dataAvailabilityColor: Color { .green }

    // MARK: - View

    public var body: some View {
        NavigationStack {
            List {
                // Pipeline Status
                Section("Pipeline Status") {
                    PipelineStatusRow(
                        title: "Data Availability",
                        subtitle: dataAvailabilityText,
                        icon: dataAvailabilityIcon,
                        color: dataAvailabilityColor
                    )

                    PipelineStatusRow(
                        title: "Last Export",
                        subtitle: lastExportText,
                        icon: "doc.text",
                        color: .blue
                    )

                    PipelineStatusRow(
                        title: "Export Destination",
                        subtitle: exportDestination,
                        icon: "folder",
                        color: .green
                    )
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
                            Text(autoExportTime).foregroundStyle(.secondary)
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
                        PipelineTroubleshootingView()
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
            ExportConfigurationSheet(
                selectedDate: $selectedDate,
                exportDestination: $exportDestination,
                destinations: destinationOptions,
                onExport: performExport
            )
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
                }
            } catch {
                await MainActor.run {
                    logger.error("Failed to populate today's data: \(error.localizedDescription)")
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
                }
            } catch {
                await MainActor.run {
                    logger.error("Failed to populate last week's data: \(error.localizedDescription)")
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
                }
            } catch {
                await MainActor.run {
                    logger.error("Failed to populate historical data: \(error.localizedDescription)")
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
                    lastExportURL = outputURL
                    logger.info("Successfully exported data for \(dateString) to \(outputURL.path)")
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
                }
                try? await Task.sleep(nanoseconds: 800_000_000)
                await MainActor.run {
                    isExporting = false
                    exportStatus = ""
                }
            }
        }
    }

    private func refreshStatus() {
        // Hook up to your availability checks when ready
    }

    private func updateAutoExportSchedule() {
        // Wire this into background task scheduling
    }

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
                        ForEach(destinations, id: \.self) { Text($0).tag($0) }
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

// MARK: - Placeholder Views

public struct ExportHistoryView: View {
    public var body: some View {
        Text("Export History")
            .navigationTitle("Export History")
    }
}

public struct PipelineDocumentationView: View {
    public var body: some View {
        Text("Pipeline Documentation")
            .navigationTitle("Documentation")
    }
}

public struct PipelineTroubleshootingView: View {
    public var body: some View {
        Text("Troubleshooting")
            .navigationTitle("Troubleshooting")
    }
}

#Preview {
    MLPipelineSettingsView()
        .modelContainer(for: ProbeTick.self, inMemory: true)
}
