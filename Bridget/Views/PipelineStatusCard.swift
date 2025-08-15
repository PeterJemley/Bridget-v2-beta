import SwiftUI
import SwiftData

struct PipelineStatusCard: View {
    @Bindable var viewModel: PipelineStatusViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Pipeline Status")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Refresh") {
                    viewModel.refreshStatus()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            VStack(spacing: 12) {
                PipelineStatusRow(
                    title: "Data Availability",
                    subtitle: viewModel.dataAvailabilityStatus,
                    icon: viewModel.isPipelineHealthy ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    color: viewModel.isPipelineHealthy ? .green : .orange
                )

                PipelineStatusRow(
                    title: "Last Population",
                    subtitle: viewModel.populationStatus,
                    icon: "arrow.down.circle.fill",
                    color: .blue
                )

                PipelineStatusRow(
                    title: "Last Export",
                    subtitle: viewModel.exportStatus,
                    icon: "square.and.arrow.up.circle.fill",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

#Preview {
    struct PreviewContainer: View {
        @Environment(\.modelContext) private var modelContext
        @State private var viewModel: PipelineStatusViewModel?
        
        var body: some View {
            Group {
                if let viewModel {
                    PipelineStatusCard(viewModel: viewModel)
                        .padding()
                } else {
                    // Show empty state instead of loading message
                    EmptyView() // Placeholder for loading or empty state
                }
            }
            .onAppear {
                if viewModel == nil {
                    viewModel = PipelineStatusViewModel(
                        backgroundManager: MLPipelineBackgroundManager.shared,
                        modelContext: modelContext
                    )
                }
            }
        }
    }
    
    return PreviewContainer()
        .modelContainer(for: [
            BridgeEvent.self,
            RoutePreference.self,
            TrafficInferenceCache.self,
            UserRouteHistory.self,
            ProbeTick.self
        ], inMemory: true)
}
