import SwiftUI
import SwiftData

/// The main content view with a home screen approach focused on user functionality.
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState: AppStateModel?
    @State private var pipelineViewModel: MLPipelineViewModel?
    @State private var showingSettings = false
    @State private var showingBridgeStatus = false
    @State private var showingTrafficAlerts = false
    @State private var showingMyRoutes = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Text("Bridget")
                            .font(.largeTitle)
                            .bold()
                        Text("Seattle Bridge Navigation")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 20)
                    
                    // Main Action Buttons
                    VStack(spacing: 16) {
                        // Find Route - Primary Action
                        NavigationLink {
                            if let appState {
                                RouteListView(appState: appState)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "map.fill")
                                    .font(.title2)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Find Route")
                                        .font(.headline)
                                    Text("Navigate to your destination")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Bridge Status
                        Button {
                            showingBridgeStatus = true
                        } label: {
                            HStack {
                                Image(systemName: "bridge.fill")
                                    .font(.title2)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Bridge Status")
                                        .font(.headline)
                                    Text("Real-time bridge conditions")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // Traffic Alerts
                        Button {
                            showingTrafficAlerts = true
                        } label: {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.title2)
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Traffic Alerts")
                                        .font(.headline)
                                    Text("Current traffic issues")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                        
                        // My Routes
                        Button {
                            showingMyRoutes = true
                        } label: {
                            HStack {
                                Image(systemName: "heart.fill")
                                    .font(.title2)
                                    .foregroundStyle(.red)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("My Routes")
                                        .font(.headline)
                                    Text("Saved and favorite routes")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.secondary)
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal)
                    
                    // Settings Button (Smaller, less prominent)
                    Button {
                        showingSettings = true
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                                .font(.title3)
                            Text("Settings")
                                .font(.subheadline)
                            Spacer()
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                }
                .padding(.bottom, 40)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showingSettings) {
            NavigationStack {
                SettingsTabView()
            }
        }
        .sheet(isPresented: $showingBridgeStatus) {
            NavigationStack {
                BridgeStatusView()
            }
        }
        .sheet(isPresented: $showingTrafficAlerts) {
            NavigationStack {
                TrafficAlertsView()
            }
        }
        .sheet(isPresented: $showingMyRoutes) {
            NavigationStack {
                MyRoutesView()
            }
        }
        .onAppear {
            // Initialize view models in background
            if appState == nil {
                appState = AppStateModel(modelContext: modelContext)
            }
            if pipelineViewModel == nil {
                pipelineViewModel = MLPipelineViewModel(modelContext: modelContext)
            }
        }
    }
}

#if DEBUG
#Preview {
    ContentView()
        .modelContainer(for: [
            BridgeEvent.self,
            RoutePreference.self,
            TrafficInferenceCache.self,
            UserRouteHistory.self,
            ProbeTick.self
        ], inMemory: true)
}
#endif
