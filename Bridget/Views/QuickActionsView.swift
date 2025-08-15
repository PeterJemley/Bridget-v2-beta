import SwiftUI
import SwiftData

struct QuickActionsView: View {
    @Bindable var viewModel: QuickActionsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.title2)
                .bold()

            VStack(spacing: 12) {
                Button {
                    Task {
                        await viewModel.populateTodayData()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                            .foregroundStyle(.blue)
                        Text("Populate Today's Data")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

                Button {
                    Task {
                        viewModel.backgroundManager.triggerBackgroundTask(.dataExport)
                        viewModel.backgroundManager.updateLastExportDate()
                        viewModel.backgroundManager.addActivity(
                            title: "Data Export",
                            description: "Exported today's probe tick data",
                            type: .dataExport
                        )
                        viewModel.notificationManager.showSuccessNotification(
                            title: "Data Export Complete",
                            body: "Today's data has been successfully exported.",
                            operation: .dataExport
                        )
                        viewModel.lastOperationResult = "Today's data exported successfully."
                    }
                } label: {
                    HStack {
                        Image(systemName: "square.and.arrow.up.circle.fill")
                            .foregroundStyle(.purple)
                        Text("Export Today's Data")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)

                Button {
                    Task {
                        await viewModel.runMaintenance()
                    }
                } label: {
                    HStack {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .foregroundStyle(.orange)
                        Text("Run Maintenance")
                        Spacer()
                    }
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoading)
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }

            if let result = viewModel.lastOperationResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .padding()
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    QuickActionsView(viewModel: QuickActionsViewModel(
        modelContext: try! ModelContainer(for: ProbeTick.self).mainContext,
        backgroundManager: MLPipelineBackgroundManager.shared,
        notificationManager: MLPipelineNotificationManager.shared
    ))
    .padding()
}
