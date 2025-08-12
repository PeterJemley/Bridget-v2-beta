//
//  BridgetApp.swift
//  Bridget
//
//  ## App
//  ## Purpose
//  Main application entry point with SwiftData configuration and ML pipeline integration
//  ## Dependencies
//  - SwiftUI framework
//  - SwiftData framework
//  - BackgroundTasks framework
//  - ContentView (main UI)
//  - SwiftData models (BridgeEvent, RoutePreference, TrafficInferenceCache, UserRouteHistory, ProbeTick)
//  - MLPipelineBackgroundManager (automated pipeline operations)
//  - MLPipelineNotificationManager (user notifications)
//  ## Integration Points
//  - Configures SwiftData ModelContainer
//  - Sets up main ContentView
//  - Provides shared model container to views
//  - Registers ML pipeline background tasks
//  - Manages app lifecycle for pipeline operations
//  ## Key Features
//  - SwiftData schema configuration
//  - ModelContainer setup with persistence
//  - Main app window configuration
//  - ML pipeline background task registration
//  - Notification system initialization
//  - Error handling for container creation
//

import SwiftData
import SwiftUI
import BackgroundTasks
import OSLog

struct AppLifecycleObserver: View {
    let onDidBecomeActive: () -> Void
    let onWillResignActive: () -> Void
    let onDidEnterBackground: () -> Void
    let onWillEnterForeground: () -> Void

    var body: some View {
        Color.clear // Invisible view
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                onDidBecomeActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
                onWillResignActive()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                onDidEnterBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                onWillEnterForeground()
            }
    }
}

/// The main application entry point for the Bridget app.
///
/// This app struct configures SwiftData for persistence, sets up the main
/// application window with the ContentView as the root view, and integrates
/// the ML Training Data Pipeline for automated data collection and export.
///
/// ## Overview
///
/// The `BridgetApp` is responsible for initializing the application and configuring
/// essential services like SwiftData for data persistence and the ML pipeline for
/// automated data operations. It creates the main window, provides the shared model
/// container to all child views, and manages background tasks for the pipeline.
///
/// ## Key Features
///
/// - **SwiftData Configuration**: Sets up ModelContainer with persistence
/// - **Schema Management**: Configures data models for persistence including ProbeTick
/// - **Window Management**: Creates and configures the main app window
/// - **ML Pipeline Integration**: Background task registration and management
/// - **Notification System**: User feedback for pipeline operations
/// - **Error Handling**: Graceful handling of container creation failures
/// - **Model Container**: Provides shared data access to all views
///
/// ## ML Pipeline Integration
///
/// The app automatically integrates with the ML Training Data Pipeline:
/// - **Background Tasks**: Registers automated data population and export tasks
/// - **Data Collection**: Automatically populates ProbeTick data daily
/// - **Data Export**: Automatically exports NDJSON files for ML training
/// - **User Notifications**: Keeps users informed about pipeline operations
/// - **Health Monitoring**: Tracks pipeline health and maintenance
///
/// ## Usage
///
/// The app is automatically launched by the system when the user opens Bridget.
/// ML pipeline operations run automatically in the background based on user
/// configuration. Users can manage pipeline settings through the MLPipelineSettingsView.
///
/// ## Topics
///
/// ### Configuration
/// - SwiftData schema setup with comprehensive domain models
/// - ModelContainer configuration with persistence
/// - Window group setup with model container injection
/// - ML pipeline background task registration
///
/// ### Data Persistence
/// - Uses SwiftData for automatic data persistence
/// - Configures shared model container for all views
/// - Handles container creation errors gracefully
/// - Includes ProbeTick model for ML training data
///
/// ### ML Pipeline
/// - Automated daily data population from BridgeEvent records
/// - Scheduled NDJSON export for ML training datasets
/// - Background task management for iOS
/// - User notification system for operation status
@main
struct BridgetApp: App {
    // MARK: - Model Container

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            BridgeEvent.self,
            RoutePreference.self,
            TrafficInferenceCache.self,
            UserRouteHistory.self,
            ProbeTick.self, // ML training data model
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    // MARK: - ML Pipeline Services
    
    /// Background task manager for automated ML pipeline operations
    private let backgroundManager = MLPipelineBackgroundManager.shared
    
    /// Notification manager for ML pipeline user feedback
    private let notificationManager = MLPipelineNotificationManager.shared
    
    /// Logger for app lifecycle events
    private let logger = Logger(subsystem: "Bridget", category: "App")

    // MARK: - App Scene

    var body: some Scene {
        WindowGroup {
            VStack {
                ContentView()
                AppLifecycleObserver(
                    onDidBecomeActive: handleAppDidBecomeActive,
                    onWillResignActive: handleAppWillResignActive,
                    onDidEnterBackground: handleAppDidEnterBackground,
                    onWillEnterForeground: handleAppWillEnterForeground
                )
            }
            .task { initializeMLPipeline() }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - ML Pipeline Initialization
    
    /// Initializes the ML Training Data Pipeline and related services.
    ///
    /// This method is called when the app first launches and sets up:
    /// - Background task registration with the system
    /// - Initial pipeline scheduling
    /// - Notification system configuration
    /// - Pipeline health monitoring
    private func initializeMLPipeline() {
        logger.info("Initializing ML Training Data Pipeline")
        
        // Register background tasks
        backgroundManager.registerBackgroundTasks()
        
        // Schedule initial pipeline execution
        backgroundManager.scheduleNextExecution()
        
        // Show welcome notification if first launch
        if UserDefaults.standard.object(forKey: "MLPipelineFirstLaunch") == nil {
            showWelcomeNotification()
            UserDefaults.standard.set(Date(), forKey: "MLPipelineFirstLaunch")
        }
        
        logger.info("ML Training Data Pipeline initialized successfully")
    }
    
    // MARK: - App Lifecycle Management
    
    /// Handles app becoming active (foreground).
    ///
    /// When the app becomes active, we:
    /// - Refresh pipeline status
    /// - Check for pending operations
    /// - Update user interface
    private func handleAppDidBecomeActive() {
        logger.info("App became active")
        
        // Refresh pipeline status
        backgroundManager.scheduleNextExecution()
        
        // Check for any pending notifications or operations
        checkPipelineStatus()
    }
    
    /// Handles app resigning active (background).
    ///
    /// When the app goes to background, we:
    /// - Ensure background tasks are properly scheduled
    /// - Save any pending state
    /// - Prepare for background execution
    private func handleAppWillResignActive() {
        logger.info("App will resign active")
        
        // Ensure background tasks are scheduled
        backgroundManager.scheduleNextExecution()
    }
    
    /// Handles app entering background.
    ///
    /// When the app enters background, we:
    /// - Finalize background task scheduling
    /// - Clean up any temporary resources
    /// - Prepare for extended background execution
    private func handleAppDidEnterBackground() {
        logger.info("App entered background")
        
        // Finalize background task scheduling
        backgroundManager.scheduleNextExecution()
        
        // Show notification about background operations if enabled
        if notificationManager.isNotificationsEnabled {
            notificationManager.showProgressNotification(
                title: "ML Pipeline Active",
                body: "Pipeline operations will continue in the background",
                operation: .maintenance,
                progress: 1.0
            )
        }
    }
    
    /// Handles app entering foreground.
    ///
    /// When the app enters foreground, we:
    /// - Refresh pipeline status
    /// - Check for completed operations
    /// - Update user interface
    private func handleAppWillEnterForeground() {
        logger.info("App will enter foreground")
        
        // Refresh pipeline status
        checkPipelineStatus()
    }
    
    // MARK: - Pipeline Status Management
    
    /// Checks the current status of the ML pipeline and updates the UI accordingly.
    ///
    /// This method:
    /// - Queries the current pipeline state
    /// - Checks for any completed operations
    /// - Updates user interface elements
    /// - Shows relevant notifications
    private func checkPipelineStatus() {
        // Check if we have recent data
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        if let lastPopulation = backgroundManager.lastPopulationDate,
           let lastExport = backgroundManager.lastExportDate {
            
            let populationAge = calendar.dateComponents([.day], from: lastPopulation, to: today).day ?? 0
            let exportAge = calendar.dateComponents([.day], from: lastExport, to: today).day ?? 0
            
            // Show notifications for stale data if enabled
            if populationAge > 1 && notificationManager.isNotificationTypeEnabled(.health) {
                notificationManager.showHealthNotification(
                    title: "Pipeline Health Warning",
                    body: "Data population is \(populationAge) days old. Consider refreshing data.",
                    healthIssue: .dataStale
                )
            }
            
            if exportAge > 1 && notificationManager.isNotificationTypeEnabled(.health) {
                notificationManager.showHealthNotification(
                    title: "Pipeline Health Warning",
                    body: "Data export is \(exportAge) days old. Consider running export.",
                    healthIssue: .exportFailed
                )
            }
        }
    }
    
    // MARK: - User Experience
    
    /// Shows a welcome notification for first-time users.
    ///
    /// This notification introduces users to the ML pipeline and explains
    /// what operations will happen automatically in the background.
    private func showWelcomeNotification() {
        notificationManager.showSuccessNotification(
            title: "Welcome to Bridget ML Pipeline!",
            body: "Your ML training data pipeline is now active. Data will be collected and exported automatically.",
            operation: .maintenance
        )
    }
}

