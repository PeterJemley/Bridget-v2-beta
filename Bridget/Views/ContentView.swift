import SwiftUI
import SwiftData

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
    @Environment(\.modelContext) private var modelContext
    @State private var appState: AppStateModel?
    @State private var selectedTab: Tab = .routes

    enum Tab: Int { case routes = 0, pipeline = 1, settings = 2 }

    var body: some View {
        Group {
            if let appState {
                TabView(selection: $selectedTab) {
                    // ROUTES
                    NavigationStack {
                        RouteListView(appState: appState)
                    }
                    .tabItem { Label("Routes", systemImage: "map") }
                    .tag(Tab.routes)

                    // ML PIPELINE
                    NavigationStack {
                        MLPipelineTabView()
                    }
                    .tabItem { Label("ML Pipeline", systemImage: "brain.head.profile") }
                    .tag(Tab.pipeline)

                    // SETTINGS
                    NavigationStack {
                        SettingsTabView()
                    }
                    .tabItem { Label("Settings", systemImage: "gear") }
                    .tag(Tab.settings)
                }
                .toolbar(.visible, for: .tabBar)
                .toolbarBackground(.automatic, for: .tabBar)
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
    @Environment(\.modelContext) private var modelContext
    @Bindable private var backgroundManager = MLPipelineBackgroundManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Pipeline Status Card
            PipelineStatusCard()
                .padding(.horizontal)
                .padding(.top, 20)
            
            // Quick Actions
            QuickActionsView()
                .padding(.horizontal)
                .padding(.top, 24)
            
            // Recent Activity
            RecentActivityView()
                .padding(.horizontal)
                .padding(.top, 24)
            
            // Force content to bottom
            Spacer(minLength: 0)
        }
        .navigationTitle("ML Pipeline")
        .navigationBarTitleDisplayMode(.large)
    }
}

// MARK: - Pipeline Status Card

/// Displays the current status of the ML pipeline.
struct PipelineStatusCard: View {
    @Bindable private var backgroundManager = MLPipelineBackgroundManager.shared
    @Environment(\.modelContext) private var modelContext
    @State private var dataAvailabilityStatus = "Checking..."

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                Text("Pipeline Status")
                    .font(.headline)
                Spacer()
                StatusIndicator(isHealthy: isPipelineHealthy)
            }

            VStack(alignment: .leading, spacing: 12) {
                StatusRow(
                    title: "Data Availability",
                    status: dataAvailabilityStatus,
                    icon: "externaldrive"
                )

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
                    status: backgroundManager.isAutoExportEnabled
                        ? "Enabled" : "Disabled",
                    icon: "clock.arrow.circlepath"
                )
            }
            
            // Add separator
            Divider()
                .padding(.vertical, 8)
            
            // Pipeline Management Links
            VStack(spacing: 12) {
                NavigationLink(destination: MLPipelineSettingsView()) {
                    HStack {
                        Image(systemName: "gear")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        Text("Pipeline Settings")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: ExportHistoryView()) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        Text("Export History")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())

                NavigationLink(destination: PipelineTroubleshootingView(
                    lastBackgroundTaskRun: backgroundManager.lastPopulationDate,
                    lastBackgroundTaskError: nil,
                    onRerunHealthChecks: {
                        backgroundManager.triggerBackgroundTask(.maintenance)
                    }
                )) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(.blue)
                            .frame(width: 24, height: 24)
                        Text("Pipeline Health")
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                            .font(.caption)
                    }
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .onAppear {
            updateDataAvailabilityStatus()
        }
    }

    private var isPipelineHealthy: Bool {
        // Simple health check based on recent activity
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        if let lastPopulation = backgroundManager.lastPopulationDate,
            let lastExport = backgroundManager.lastExportDate
        {
            let populationAge =
                calendar.dateComponents([.day], from: lastPopulation, to: today)
                .day ?? 0
            let exportAge =
                calendar.dateComponents([.day], from: lastExport, to: today).day
                ?? 0

            return populationAge <= 1 && exportAge <= 1
        }

        return false
    }

    private func getPopulationStatus() -> String {
        if let lastPopulation = backgroundManager.lastPopulationDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let age =
                calendar.dateComponents([.day], from: lastPopulation, to: today)
                .day ?? 0

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
            let age =
                calendar.dateComponents([.day], from: lastExport, to: today).day
                ?? 0

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

    private func getDataAvailabilityStatus() -> String {
        // This will be enhanced to check actual data availability
        // For now, return a placeholder that will be updated
        if let lastPopulation = backgroundManager.lastPopulationDate {
            let calendar = Calendar.current
            let today = calendar.startOfDay(for: Date())
            let age = calendar.dateComponents([.day], from: lastPopulation, to: today).day ?? 0
            
            if age == 0 {
                return "Available (Today)"
            } else if age == 1 {
                return "Available (Yesterday)"
            } else if age <= 7 {
                return "Available (\(age) days ago)"
            } else {
                return "Stale (\(age) days old)"
            }
        }
        return "No Data"
    }

    private func updateDataAvailabilityStatus() {
        Task {
            do {
                let descriptor = FetchDescriptor<ProbeTick>()
                let count = try modelContext.fetchCount(descriptor)
                
                await MainActor.run {
                    if count > 0 {
                        let calendar = Calendar.current
                        let today = calendar.startOfDay(for: Date())
                        
                        // Get the most recent tick
                        var recentDescriptor = FetchDescriptor<ProbeTick>(
                            sortBy: [SortDescriptor(\.tsUtc, order: .reverse)]
                        )
                        recentDescriptor.fetchLimit = 1
                        
                        if let recentTick = try? modelContext.fetch(recentDescriptor).first {
                            let age = calendar.dateComponents([.day], from: recentTick.tsUtc, to: today).day ?? 0
                            
                            if age == 0 {
                                dataAvailabilityStatus = "Available (Today) - \(count) records"
                            } else if age == 1 {
                                dataAvailabilityStatus = "Available (Yesterday) - \(count) records"
                            } else if age <= 7 {
                                dataAvailabilityStatus = "Available (\(age) days ago) - \(count) records"
                            } else {
                                dataAvailabilityStatus = "Stale (\(age) days old) - \(count) records"
                            }
                        } else {
                            dataAvailabilityStatus = "Available - \(count) records"
                        }
                    } else {
                        dataAvailabilityStatus = "No Data"
                    }
                }
            } catch {
                await MainActor.run {
                    dataAvailabilityStatus = "Error checking data"
                }
            }
        }
    }
}

// MARK: - Status Indicator

/// Visual indicator for pipeline health status.
struct StatusIndicator: View {
    let isHealthy: Bool

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(isHealthy ? .green : .red)
                .frame(width: 10, height: 10)
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 22, height: 22)
                .font(.system(size: 15, weight: .medium))
            
            Text(title)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(status)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Quick Actions View

/// Quick action buttons for common pipeline operations.
struct QuickActionsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        let _ = print(
            "🔵 [DEBUG] QuickActionsView - Model context available: true"
        )

        VStack(spacing: 20) {
            Text("Quick Actions")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                QuickActionButton(
                    title: "Populate Today",
                    icon: "calendar.badge.plus",
                    action: populateTodayData
                )
                .accessibilityIdentifier("populate-today-button")
                .frame(maxWidth: .infinity)

                QuickActionButton(
                    title: "Export Today",
                    icon: "square.and.arrow.up",
                    action: exportTodayData
                )
                .accessibilityIdentifier("export-today-button")
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal)
    }

    private func populateTodayData() {
        print("🔵 [DEBUG] Populate Today button tapped")
        print("🔵 [DEBUG] Model context available: true")

        Task {
            do {
                print("🔵 [DEBUG] Starting data population...")
                let service = ProbeTickDataService(context: modelContext)
                try await service.populateTodayProbeTicks()
                print("🔵 [DEBUG] Data population completed successfully")

                await MainActor.run {
                    // Update the background manager with the new population date
                    MLPipelineBackgroundManager.shared.updateLastPopulationDate()
                    
                    // Add activity to recent activities
                    MLPipelineBackgroundManager.shared.addActivity(
                        title: "Data Population",
                        description: "Today's data populated successfully",
                        type: .dataPopulation
                    )
                    
                    // Show success notification
                    let title = "Data Population Complete"
                    let body =
                        "Today's ProbeTick data has been populated successfully."
                    MLPipelineNotificationManager.shared
                        .showSuccessNotification(
                            title: title,
                            body: body,
                            operation: .dataPopulation
                        )
                    print("🔵 [DEBUG] Success notification sent")
                }
            } catch {
                print("🔴 [DEBUG] Data population failed: \(error)")
                await MainActor.run {
                    // Show failure notification
                    let title = "Data Population Failed"
                    let body = "Failed to populate today's data."
                    MLPipelineNotificationManager.shared
                        .showFailureNotification(
                            title: title,
                            body: body,
                            operation: .dataPopulation,
                            error: error
                        )
                    print("🔴 [DEBUG] Failure notification sent")
                }
            }
        }
    }

    private func exportTodayData() {
        print("🔵 [DEBUG] Export Today button tapped")
        print("🔵 [DEBUG] Model context available: true")

        Task {
            do {
                print("🔵 [DEBUG] Starting data export...")
                let exporter = BridgeDataExporter(context: modelContext)
                let today = Calendar.current.startOfDay(for: Date())
                let documentsPath = FileManager.default.urls(
                    for: .documentDirectory,
                    in: .userDomainMask
                ).first!
                let outputURL = documentsPath.appendingPathComponent(
                    "minutes_\(DateFormatter().string(from: today)).ndjson"
                )

                try await exporter.exportDailyNDJSON(for: today, to: outputURL)
                print("🔵 [DEBUG] Data export completed successfully")

                await MainActor.run {
                    // Update the background manager with the new export date
                    MLPipelineBackgroundManager.shared.updateLastExportDate()
                    
                    // Add activity to recent activities
                    MLPipelineBackgroundManager.shared.addActivity(
                        title: "Data Export",
                        description: "Today's data exported to Documents",
                        type: .dataExport
                    )
                    
                    // Show success notification
                    MLPipelineNotificationManager.shared
                        .showSuccessNotification(
                            title: "Export Complete",
                            body:
                                "Today's data has been exported successfully.",
                            operation: .dataExport
                        )
                    print("🔵 [DEBUG] Success notification sent")
                }
            } catch {
                print("🔴 [DEBUG] Data export failed: \(error)")
                await MainActor.run {
                    // Show failure notification
                    let title = "Export Failed"
                    let body = "Failed to export today's data."
                    MLPipelineNotificationManager.shared
                        .showFailureNotification(
                            title: title,
                            body: body,
                            operation: .dataExport,
                            error: error
                        )
                    print("🔴 [DEBUG] Failure notification sent")
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
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 24, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .background(Color.blue.opacity(0.1))
                    .clipShape(Circle())
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 12)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Recent Activity View

/// Displays recent pipeline activity and operations.
struct RecentActivityView: View {
    @Bindable private var backgroundManager = MLPipelineBackgroundManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recent Activity")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 16) {
                let activities = backgroundManager.getRecentActivities()
                
                if activities.isEmpty {
                    ActivityRow(
                        title: "No Recent Activity",
                        description: "No data population or export activity yet",
                        time: "Never",
                        status: .inProgress
                    )
                } else {
                    ForEach(activities.prefix(3)) { activity in
                        ActivityRow(
                            title: activity.title,
                            description: activity.description,
                            time: formatTimeAgo(from: activity.timestamp),
                            status: activity.type == .error ? .failure : .success
                        )
                    }
                }
            }
            .onAppear {
                // Force refresh of activities when view appears
                let _ = backgroundManager.getRecentActivities()
            }
        }
        .padding(20)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
        .padding(.horizontal)
    }

    private func formatTimeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.hour, .day], from: date, to: now)
        
        if let days = components.day, days > 0 {
            if days == 1 {
                return "1 day ago"
            } else {
                return "\(days) days ago"
            }
        } else if let hours = components.hour, hours > 0 {
            if hours == 1 {
                return "1 hour ago"
            } else {
                return "\(hours) hours ago"
            }
        } else {
            return "Just now"
        }
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
        HStack(spacing: 12) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)
                .shadow(color: status.color.opacity(0.3), radius: 2, x: 0, y: 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(time)
                .font(.caption)
                .foregroundColor(.secondary)
                .fontWeight(.medium)
        }
        .padding(.vertical, 8)
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
    @Bindable private var backgroundManager = MLPipelineBackgroundManager.shared

    var body: some View {
        List {
            Section("App") {
                NavigationLink(
                    "General Settings",
                    destination: Text("General Settings")
                )
                NavigationLink("About", destination: Text("About"))
            }
            
            Section("Data & Privacy") {
                NavigationLink(
                    "Data Usage",
                    destination: Text("Data Usage Settings")
                )
                NavigationLink(
                    "Privacy Policy",
                    destination: Text("Privacy Policy")
                )
            }
            
            Section("Support") {
                NavigationLink(
                    "Help & FAQ",
                    destination: Text("Help & FAQ")
                )
                NavigationLink(
                    "Contact Support",
                    destination: Text("Contact Support")
                )
            }
        }
        .navigationTitle("Settings")
        .listStyle(.insetGrouped)
    }
}

#Preview {
    ContentView()
}

#Preview("ML Pipeline Tab") {
    NavigationStack {
        MLPipelineTabView()
    }
    .environment(\.modelContext, try! ModelContainer(for: ProbeTick.self).mainContext)
}

#Preview("Pipeline Status Card") {
    PipelineStatusCard()
        .environment(\.modelContext, try! ModelContainer(for: ProbeTick.self).mainContext)
        .padding()
}

#Preview("Quick Actions") {
    QuickActionsView()
        .padding()
}

#Preview("Recent Activity") {
    RecentActivityView()
        .padding()
}

#Preview("Settings Tab") {
    NavigationStack {
        SettingsTabView()
    }
}

// MARK: - Conditional Modifier Extension

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}


