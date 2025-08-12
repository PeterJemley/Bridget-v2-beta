//
//  ContentView.swift
//  Bridget
//
//  Module: Views
//  Purpose: Main content view that coordinates app state and routing with ML pipeline integration
//  Dependencies:
//    - SwiftUI framework
//    - AppStateModel (for state management)
//    - RouteListView (for route display)
//    - MLPipelineSettingsView (for pipeline management)
//  Integration Points:
//    - Initializes and manages AppStateModel
//    - Coordinates with RouteListView for UI display
//    - Provides app state to child views
//    - Integrates ML pipeline settings and management
//    - Provides navigation to pipeline configuration
//  Key Features:
//    - App state initialization and management
//    - View coordination and routing
//    - Bindable state propagation
//    - ML pipeline integration and navigation
//    - Clean separation of concerns
//

import SwiftUI

/// The main content view that coordinates app state and routing with ML pipeline integration.
///
/// This view serves as the root view of the application, initializing and managing
/// the global app state, coordinating with child views for UI display, and providing
/// access to the ML Training Data Pipeline settings and management.
///
/// ## Overview
///
/// The `ContentView` is responsible for setting up the application's state management
/// and providing the main navigation structure. It initializes the `AppStateModel`,
/// passes it to child views using the Observation framework, and integrates the ML
/// pipeline settings for easy access and management.
///
/// ## Key Features
///
/// - **State Management**: Initializes and manages the global `AppStateModel`
/// - **View Coordination**: Coordinates with `RouteListView` for UI display
/// - **ML Pipeline Integration**: Provides access to pipeline settings and management
/// - **Navigation Structure**: Tab-based navigation with pipeline access
/// - **Bindable State**: Uses `@Bindable` for reactive state propagation
/// - **Clean Architecture**: Maintains separation of concerns between state and UI
///
/// ## ML Pipeline Integration
///
/// The view integrates the ML Training Data Pipeline through:
/// - **Pipeline Tab**: Dedicated tab for pipeline management
/// - **Settings Access**: Easy access to pipeline configuration
/// - **Status Display**: Pipeline status and health information
/// - **Quick Actions**: Common pipeline operations
///
/// ## Usage
///
/// ```swift
/// ContentView()
/// ```
///
/// ## Topics
///
/// ### State Management
/// - Initializes `AppStateModel` on app launch
/// - Provides state to child views via `@Bindable`
/// - Coordinates reactive updates across the view hierarchy
///
/// ### View Hierarchy
/// - Root view of the application with tab-based navigation
/// - Contains `RouteListView` as the main content
/// - Integrates `MLPipelineSettingsView` for pipeline management
/// - Provides settings and configuration access
///
/// ### ML Pipeline
/// - Dedicated pipeline management interface
/// - Pipeline status monitoring and display
/// - Quick access to common pipeline operations
/// - Integration with app lifecycle and background tasks
struct ContentView: View {
    // MARK: - Properties

    @Environment(\.modelContext) private var modelContext
    @State private var appState: AppStateModel?
    @State private var selectedTab = 0

    // MARK: - View Body

    var body: some View {
        Group {
            if let appState = appState {
                TabView(selection: $selectedTab) {
                    // Main Routes Tab
                    RouteListView(appState: appState)
                        .tabItem {
                            Image(systemName: "map")
                            Text("Routes")
                        }
                        .tag(0)
                    
                    // ML Pipeline Tab
                    MLPipelineTabView()
                        .tabItem {
                            Image(systemName: "brain.head.profile")
                            Text("ML Pipeline")
                        }
                        .tag(1)
                    
                    // Settings Tab
                    SettingsTabView()
                        .tabItem {
                            Image(systemName: "gear")
                            Text("Settings")
                        }
                        .tag(2)
                }
            } else {
                ProgressView("Initializing...")
            }
        }
        .onAppear {
            if appState == nil {
                appState = AppStateModel(modelContext: modelContext)
            }
        }
    }
}

// MARK: - ML Pipeline Tab View

/// Dedicated tab view for ML pipeline management and monitoring.
///
/// This view provides a comprehensive interface for managing the ML Training Data
/// Pipeline, including status monitoring, quick actions, and detailed settings access.
struct MLPipelineTabView: View {
    @State private var showingSettings = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 28) {
                // Pipeline Status Card
                PipelineStatusCard()
                    .padding(.horizontal)
                
                // Quick Actions
                QuickActionsView()
                
                // Recent Activity
                RecentActivityView()
                    .padding(.bottom, 20)
                
                Spacer()
                
                // Settings Button
                Button(action: { showingSettings = true }) {
                    Label("Pipeline Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor.opacity(0.9))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("ML Pipeline")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingSettings) {
                MLPipelineSettingsView()
            }
        }
    }
}

// MARK: - Pipeline Status Card

/// Displays the current status of the ML pipeline.
struct PipelineStatusCard: View {
    @ObservedObject private var backgroundManager = MLPipelineBackgroundManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.blue)
                Text("Pipeline Status")
                    .font(.headline)
                Spacer()
                StatusIndicator(isHealthy: isPipelineHealthy)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                StatusRow(
                    title: "Data Population",
                    status: getPopulationStatus(),
                    icon: "calendar.badge.plus"
                )
                
                StatusRow(
                    title: "Data Export",
                    status: getExportStatus(),
                    icon: "square.and.arrow.up"
                )
                
                StatusRow(
                    title: "Auto-Export",
                    status: backgroundManager.isAutoExportEnabled ? "Enabled" : "Disabled",
                    icon: "clock.arrow.circlepath"
                )
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.03), radius: 3, y: 2)
    }
    
    private var isPipelineHealthy: Bool {
        // Simple health check based on recent activity
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastPopulation = backgroundManager.lastPopulationDate,
           let lastExport = backgroundManager.lastExportDate {
            
            let populationAge = calendar.dateComponents([.day], from: lastPopulation, to: today).day ?? 0
            let exportAge = calendar.dateComponents([.day], from: lastExport, to: today).day ?? 0
            
            return populationAge <= 1 && exportAge <= 1
        }
        
        return false
    }
    
    private func getPopulationStatus() -> String {
        if let lastPopulation = backgroundManager.lastPopulationDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let age = calendar.dateComponents([.day], from: lastPopulation, to: today).day ?? 0
            
            if age == 0 {
                return "Today"
            } else if age == 1 {
                return "Yesterday"
            } else {
                return "\(age) days ago"
            }
        }
        return "Never"
    }
    
    private func getExportStatus() -> String {
        if let lastExport = backgroundManager.lastExportDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let age = calendar.dateComponents([.day], from: lastExport, to: today).day ?? 0
            
            if age == 0 {
                return "Today"
            } else if age == 1 {
                return "Yesterday"
            } else {
                return "\(age) days ago"
            }
        }
        return "Never"
    }
}

// MARK: - Status Indicator

/// Visual indicator for pipeline health status.
struct StatusIndicator: View {
    let isHealthy: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isHealthy ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(isHealthy ? "Healthy" : "Needs Attention")
                .font(.caption)
                .foregroundColor(isHealthy ? .green : .red)
        }
    }
}

// MARK: - Status Row

/// Individual status row for pipeline components.
struct StatusRow: View {
    let title: String
    let status: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            Text(title)
                .font(.subheadline)
            Spacer()
            Text(status)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Quick Actions View

/// Quick action buttons for common pipeline operations.
struct QuickActionsView: View {
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            Color(.systemGray6)
                .cornerRadius(12)
            
            VStack(spacing: 12) {
                Text("Quick Actions")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                HStack(spacing: 16) {
                    QuickActionButton(
                        title: "Populate Today",
                        icon: "calendar.badge.plus",
                        action: populateTodayData
                    )
                    
                    QuickActionButton(
                        title: "Export Today",
                        icon: "square.and.arrow.up",
                        action: exportTodayData
                    )
                }
            }
            .padding(8)
        }
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
    
    private func populateTodayData() {
        Task {
            do {
                let service = ProbeTickDataService(context: modelContext)
                try await service.populateTodayProbeTicks()
                
                await MainActor.run {
                    // Show success notification
                    MLPipelineNotificationManager.shared.showSuccessNotification(
                        title: "Data Population Complete",
                        body: "Today's ProbeTick data has been populated successfully.",
                        operation: .dataPopulation
                    )
                }
            } catch {
                await MainActor.run {
                    // Show failure notification
                    MLPipelineNotificationManager.shared.showFailureNotification(
                        title: "Data Population Failed",
                        body: "Failed to populate today's data.",
                        operation: .dataPopulation,
                        error: error
                    )
                }
            }
        }
    }
    
    private func exportTodayData() {
        Task {
            do {
                let exporter = BridgeDataExporter(context: modelContext)
                let today = Calendar.current.startOfDay(for: Date())
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let outputURL = documentsPath.appendingPathComponent("minutes_\(DateFormatter().string(from: today)).ndjson")
                
                try await exporter.exportDailyNDJSON(for: today, to: outputURL)
                
                await MainActor.run {
                    // Show success notification
                    MLPipelineNotificationManager.shared.showSuccessNotification(
                        title: "Export Complete",
                        body: "Today's data has been exported successfully.",
                        operation: .dataExport
                    )
                }
            } catch {
                await MainActor.run {
                    // Show failure notification
                    MLPipelineNotificationManager.shared.showFailureNotification(
                        title: "Export Failed",
                        body: "Failed to export today's data.",
                        operation: .dataExport,
                        error: error
                    )
                }
            }
        }
    }
}

// MARK: - Quick Action Button

/// Individual quick action button.
struct QuickActionButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Activity View

/// Displays recent pipeline activity and operations.
struct RecentActivityView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 8) {
                ActivityRow(
                    title: "Data Population",
                    description: "Today's data populated successfully",
                    time: "2 hours ago",
                    status: .success
                )
                
                ActivityRow(
                    title: "Data Export",
                    description: "Yesterday's data exported to Documents",
                    time: "1 day ago",
                    status: .success
                )
            }
            .padding(8)
        }
        .background(Color(.systemGray6))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.vertical, 4)
    }
}

// MARK: - Activity Row

/// Individual activity row for recent operations.
struct ActivityRow: View {
    let title: String
    let description: String
    let time: String
    let status: ActivityStatus
    
    var body: some View {
        HStack {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(time)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Activity Status

/// Status enum for activity rows.
enum ActivityStatus {
    case success
    case failure
    case inProgress
    
    var color: Color {
        switch self {
        case .success:
            return .green
        case .failure:
            return .red
        case .inProgress:
            return .orange
        }
    }
}

// MARK: - Settings Tab View

/// Settings tab view for app configuration.
struct SettingsTabView: View {
    var body: some View {
        NavigationView {
            List {
                Section("ML Pipeline") {
                    NavigationLink("Pipeline Settings", destination: MLPipelineSettingsView())
                    NavigationLink("Export History", destination: Text("Export History"))
                    NavigationLink("Pipeline Health", destination: Text("Pipeline Health"))
                }
                
                Section("App") {
                    NavigationLink("General Settings", destination: Text("General Settings"))
                    NavigationLink("About", destination: Text("About"))
                }
            }
            .navigationTitle("Settings")
        }
    }
}

#Preview {
    ContentView()
}
