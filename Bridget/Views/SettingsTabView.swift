import SwiftUI

struct SettingsTabView: View {
    @State private var settingsViewModel = SettingsViewModel()
    @State private var showingDocumentation = false
    @State private var showingTroubleshooting = false

    @State private var showingPipelineSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section("Pipeline Settings") {
                    PipelineSettingsView(settingsViewModel: settingsViewModel)
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingPipelineSettings) {
                PipelineSettingsView(settingsViewModel: settingsViewModel)
            }
            .sheet(isPresented: $showingDocumentation) {
                NavigationStack {
                    PipelineDocumentationView()
                }
            }
            .sheet(isPresented: $showingTroubleshooting) {
                NavigationStack {
                    PipelineTroubleshootingView(
                        lastBackgroundTaskRun: MLPipelineBackgroundManager.shared.lastPopulationDate,
                        lastBackgroundTaskError: nil, // TODO: Add error tracking to background manager
                        onRerunHealthChecks: {
                            MLPipelineBackgroundManager.shared.triggerBackgroundTask(.maintenance)
                        }
                    )
                }
            }

        }
    }
}

#Preview {
    SettingsTabView()
}
