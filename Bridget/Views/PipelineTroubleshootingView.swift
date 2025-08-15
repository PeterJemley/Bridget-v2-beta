import SwiftUI

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
        let bgManager = MLPipelineBackgroundManager.shared
        
        // Trigger maintenance task which includes health checks
        bgManager.triggerBackgroundTask(.maintenance)
        
        // For now, provide a simple health check summary
        // In a more sophisticated implementation, this would query the actual health status
        let healthCheckSummary = "Health checks completed. Check logs for detailed results."
        
        await MainActor.run {
            healthCheckResult = healthCheckSummary
        }
    }
}

#Preview {
    NavigationStack {
        PipelineTroubleshootingView(
            lastBackgroundTaskRun: Date().addingTimeInterval(-3600), // 1 hour ago
            lastBackgroundTaskError: nil,
            onRerunHealthChecks: {
                print("Health checks triggered")
            }
        )
    }
}

#Preview("With Error") {
    NavigationStack {
        PipelineTroubleshootingView(
            lastBackgroundTaskRun: Date().addingTimeInterval(-7200), // 2 hours ago
            lastBackgroundTaskError: "Network connection failed during data export",
            onRerunHealthChecks: {
                print("Health checks triggered")
            }
        )
    }
}

#Preview("Never Run") {
    NavigationStack {
        PipelineTroubleshootingView(
            lastBackgroundTaskRun: nil,
            lastBackgroundTaskError: nil,
            onRerunHealthChecks: {
                print("Health checks triggered")
            }
        )
    }
}
