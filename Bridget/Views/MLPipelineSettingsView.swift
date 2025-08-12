//
//  MLPipelineSettingsView.swift
//  Bridget
//
//  Purpose: Integrated settings and management interface for the ML Training Data Pipeline
//

import SwiftUI
import SwiftData
import OSLog

/// Integrated settings and management interface for the ML Training Data Pipeline.
///
/// This view provides a user-friendly interface for:
/// - Monitoring pipeline status and data availability
/// - Manually triggering data population and exports
/// - Viewing export history and statistics
/// - Configuring automated data collection
/// - Managing export destinations and schedules
///
/// ## Integration Points
///
/// - **ProbeTickDataService**: For data population and management
/// - **BridgeDataExporter**: For NDJSON export operations
/// - **SwiftData**: For data persistence and querying
/// - **UserDefaults**: For configuration and preferences
///
/// ## Usage
///
/// This view is typically presented as a sheet or navigation destination
/// from the main app settings or admin panel.
struct MLPipelineSettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var isExporting = false
    @State private var exportProgress = 0.0
    @State private var exportStatus = ""
    @State private var showingExportSheet = false
    @State private var selectedDate = Date()
    @State private var exportDestination = UserDefaults.standard.string(forKey: "MLExportDestination") ?? "Documents"
    @State private var autoExportEnabled = UserDefaults.standard.bool(forKey: "MLAutoExportEnabled")
    @State private var autoExportTime = UserDefaults.standard.string(forKey: "MLAutoExportTime") ?? "01:00"
    
    private let logger = Logger(subsystem: "Bridget", category: "MLPipeline")
    
    var body: some View {
        NavigationView {
            List {
                // Pipeline Status Section
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
                .padding(.vertical, 6)
                .listSectionSeparator(.visible)
                .listSectionSeparatorTint(.gray.opacity(0.3))
                .headerProminence(.increased)
                
                // Data Management Section
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
                        Label("Populate Historical Data", systemImage: "calendar.badge.exclamationmark")
                    }
                    .disabled(isExporting)
                }
                .padding(.vertical, 6)
                .listSectionSeparator(.visible)
                .listSectionSeparatorTint(.gray.opacity(0.3))
                .headerProminence(.increased)
                
                // Export Section
                Section("Export Operations") {
                    Button(action: { showingExportSheet = true }) {
                        Label("Export Today's Data", systemImage: "square.and.arrow.up")
                    }
                    .disabled(isExporting)
                    
                    if isExporting {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Exporting...")
                                .font(.headline)
                            Text(exportStatus)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            ProgressView(value: exportProgress)
                                .progressViewStyle(LinearProgressViewStyle())
                        }
                        .padding(.vertical, 6)
                    }
                }
                .padding(.vertical, 6)
                .listSectionSeparator(.visible)
                .listSectionSeparatorTint(.gray.opacity(0.3))
                .headerProminence(.increased)
                
                // Automation Section
                Section("Automation") {
                    Toggle("Enable Daily Auto-Export", isOn: $autoExportEnabled)
                        .padding(.vertical, 2)
                        .onChange(of: autoExportEnabled) { _, newValue in
                            UserDefaults.standard.set(newValue, forKey: "MLAutoExportEnabled")
                            updateAutoExportSchedule()
                        }
                    
                    if autoExportEnabled {
                        HStack {
                            Text("Export Time")
                            Spacer()
                            Text(autoExportTime)
                                .foregroundColor(.secondary)
                        }
                        .contentShape(Rectangle())
                        .padding(.vertical, 2)
                        .onTapGesture {
                            showTimePicker()
                        }
                    }
                }
                .padding(.vertical, 6)
                .listSectionSeparator(.visible)
                .listSectionSeparatorTint(.gray.opacity(0.3))
                .headerProminence(.increased)
                
                // Information Section
                Section("Information") {
                    NavigationLink("Export History", destination: ExportHistoryView())
                    NavigationLink("Pipeline Documentation", destination: PipelineDocumentationView())
                    NavigationLink("Troubleshooting", destination: PipelineTroubleshootingView())
                }
                .padding(.vertical, 6)
                .listSectionSeparator(.visible)
                .listSectionSeparatorTint(.gray.opacity(0.3))
                .headerProminence(.increased)
            }
            .navigationTitle("ML Pipeline")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarLeading) {
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
                onExport: performExport
            )
        }
        .onAppear {
            refreshStatus()
        }
    }
    
    // MARK: - Computed Properties
    
    private var dataAvailabilityText: String {
        // This would query the actual data availability
        return "Today: Available • Last Week: Available • Historical: Partial"
    }
    
    private var dataAvailabilityIcon: String {
        return "checkmark.circle.fill"
    }
    
    private var dataAvailabilityColor: Color {
        return .green
    }
    
    private var lastExportText: String {
        let lastExport = UserDefaults.standard.object(forKey: "MLLastExportDate") as? Date
        if let lastExport = lastExport {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            return formatter.string(from: lastExport)
        }
        return "Never"
    }
    
    // MARK: - Actions
    
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
                let endDate = Date()
                try await service.populateHistoricalProbeTicks(from: startDate, to: endDate)
                
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
                exportProgress = 0.0
                exportStatus = "Preparing export..."
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
                    exportStatus = "Exporting data for \(dateString)..."
                    exportProgress = 0.3
                }
                
                try await exporter.exportDailyNDJSON(for: date, to: outputURL)
                
                await MainActor.run {
                    exportStatus = "Export completed successfully!"
                    exportProgress = 1.0
                    
                    // Update last export date
                    UserDefaults.standard.set(Date(), forKey: "MLLastExportDate")
                    
                    // Save export destination
                    UserDefaults.standard.set(destination, forKey: "MLExportDestination")
                    
                    logger.info("Successfully exported data for \(dateString) to \(outputURL.path)")
                }
                
                // Reset after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    isExporting = false
                    exportProgress = 0.0
                    exportStatus = ""
                }
                
            } catch {
                await MainActor.run {
                    exportStatus = "Export failed: \(error.localizedDescription)"
                    exportProgress = 0.0
                    logger.error("Export failed: \(error.localizedDescription)")
                }
                
                // Reset after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    isExporting = false
                    exportStatus = ""
                }
            }
        }
    }
    
    private func refreshStatus() {
        // This would refresh the UI with current data availability
        // For now, we'll just trigger a UI update
    }
    
    private func updateAutoExportSchedule() {
        // This would update the system's auto-export schedule
        // Implementation depends on your background task strategy
    }
    
    private func showTimePicker() {
        // This would show a time picker for auto-export time
        // Implementation depends on your UI preferences
    }
    
    private func getExportPath(for destination: String) -> URL {
        switch destination {
        case "Documents":
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        case "Downloads":
            return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        default:
            return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        }
    }
}

// MARK: - Supporting Views

struct PipelineStatusRow: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 2)
    }
}

struct ExportConfigurationSheet: View {
    @Binding var selectedDate: Date
    @Binding var exportDestination: String
    let onExport: (Date, String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private let destinations = ["Documents", "Downloads"]
    
    var body: some View {
        NavigationView {
            Form {
                Section("Export Configuration") {
                    DatePicker("Export Date", selection: $selectedDate, displayedComponents: .date)
                        .padding(.vertical, 4)
                    
                    Picker("Export Destination", selection: $exportDestination) {
                        ForEach(destinations, id: \.self) { destination in
                            Text(destination).tag(destination)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section {
                    Button("Start Export") {
                        onExport(selectedDate, exportDestination)
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 8)
                }
            }
            .navigationTitle("Export Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Placeholder Views (to be implemented)

struct ExportHistoryView: View {
    var body: some View {
        Text("Export History")
            .navigationTitle("Export History")
    }
}

struct PipelineDocumentationView: View {
    var body: some View {
        Text("Pipeline Documentation")
            .navigationTitle("Documentation")
    }
}

struct PipelineTroubleshootingView: View {
    var body: some View {
        Text("Troubleshooting")
            .navigationTitle("Troubleshooting")
    }
}

#Preview {
    MLPipelineSettingsView()
        .modelContainer(for: ProbeTick.self, inMemory: true)
}
