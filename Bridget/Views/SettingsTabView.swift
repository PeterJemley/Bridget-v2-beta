import SwiftUI
import SwiftData

struct SettingsTabView: View {
  @Environment(\.modelContext) private var modelContext

  @State private var settingsViewModel = SettingsViewModel()

  // Existing sheets
  @State private var showingTroubleshooting = false

  // Developer tools presentation state
  @AppStorage("enableDeveloperTools") private var enableDeveloperTools = false
  @State private var pipelineViewModel: MLPipelineViewModel?

  @State private var showingPipelineDashboard = false
  @State private var showingMLTraining = false
  @State private var showingMetrics = false
  @State private var showingPluginManagement = false

  var body: some View {
    NavigationStack {
      List {
        // Render settings as native sections for HIG-compliant spacing/separators
        PipelineSettingsView(settingsViewModel: settingsViewModel)

        Section("Developer Tools") {
          Toggle("Enable Developer Tools", isOn: $enableDeveloperTools)

          if enableDeveloperTools {
            // Each tool as its own row for system Settings look
            Button {
              showingPipelineDashboard = true
            } label: {
              HStack {
                Label("Pipeline Dashboard", systemImage: "rectangle.3.group")
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.tertiary)
                  .font(.footnote)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Pipeline Dashboard")

            Button {
              showingMLTraining = true
            } label: {
              HStack {
                Label("ML Training", systemImage: "brain.head.profile")
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.tertiary)
                  .font(.footnote)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open ML Training")

            Button {
              showingMetrics = true
            } label: {
              HStack {
                Label("Metrics Dashboard", systemImage: "chart.bar.doc.horizontal")
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.tertiary)
                  .font(.footnote)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Metrics Dashboard")

            Button {
              showingPluginManagement = true
            } label: {
              HStack {
                Label("Plugin Management", systemImage: "puzzlepiece.extension")
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.tertiary)
                  .font(.footnote)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Plugin Management")

            Button {
              showingTroubleshooting = true
            } label: {
              HStack {
                Label("Troubleshooting", systemImage: "stethoscope")
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.tertiary)
                  .font(.footnote)
              }
              .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open Troubleshooting")
          }
        }
      }
      .listStyle(.insetGrouped)
      .navigationTitle("Settings")

      .sheet(isPresented: $showingTroubleshooting) {
        NavigationStack {
          PipelineTroubleshootingView(
            lastBackgroundTaskRun: MLPipelineBackgroundManager.shared.lastPopulationDate,
            lastBackgroundTaskError: nil,  // TODO: Add error tracking to background manager
            onRerunHealthChecks: {
              MLPipelineBackgroundManager.shared.triggerBackgroundTask(.maintenance)
            }
          )
        }
      }
      // Developer Tools sheets
      .sheet(isPresented: $showingPipelineDashboard) {
        NavigationStack {
          if let vm = pipelineViewModel {
            ScrollView {
              VStack(spacing: 16) {
                PipelineStatusCard(viewModel: vm.pipelineStatus)
                QuickActionsView(viewModel: vm.quickActions)
                RecentActivityView(viewModel: vm.recentActivity)
              }
              .padding()
            }
            .refreshable {
              vm.pipelineStatus.refreshStatus()
              vm.recentActivity.refreshActivities()
            }
            .navigationTitle("Pipeline Dashboard")
            .navigationBarTitleDisplayMode(.large)
          } else {
            ProgressView("Loading…")
              .padding()
          }
        }
      }
      .sheet(isPresented: $showingMLTraining) {
        NavigationStack {
          if let vm = pipelineViewModel {
            MLPipelineTabView(viewModel: vm)
              .navigationTitle("ML Training")
          } else {
            ProgressView("Loading…")
              .padding()
          }
        }
      }
      .sheet(isPresented: $showingMetrics) {
        NavigationStack {
          PipelineMetricsDashboard()
        }
      }
      .sheet(isPresented: $showingPluginManagement) {
        NavigationStack {
          PipelinePluginManagementView()
        }
      }
      .onAppear {
        if pipelineViewModel == nil {
          pipelineViewModel = MLPipelineViewModel(modelContext: modelContext)
        }
      }
    }
  }
}

#Preview {
  SettingsTabView()
}
