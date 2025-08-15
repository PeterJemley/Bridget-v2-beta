import SwiftUI

struct RecentActivityView: View {
    @Bindable var viewModel: RecentActivityViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Recent Activity")
                    .font(.title2)
                    .bold()
                Spacer()
                Button("Refresh") {
                    viewModel.refreshActivities()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if viewModel.recentActivities.isEmpty {
                Text("No recent activities")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.recentActivities.prefix(5)) { activity in
                        ActivityRow(activity: activity, viewModel: viewModel)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

struct ActivityRow: View {
    let activity: PipelineActivity
    let viewModel: RecentActivityViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconForActivityType(activity.type))
                .foregroundStyle(colorForActivityType(activity.type))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(activity.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            Text(viewModel.formatTimeAgo(from: activity.timestamp))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private func iconForActivityType(_ type: ActivityType) -> String {
        switch type {
        case .dataPopulation:
            return "arrow.down.circle.fill"
        case .dataExport:
            return "square.and.arrow.up.circle.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }

    private func colorForActivityType(_ type: ActivityType) -> Color {
        switch type {
        case .dataPopulation:
            return .blue
        case .dataExport:
            return .purple
        case .maintenance:
            return .orange
        case .error:
            return .red
        }
    }
}

#Preview {
    RecentActivityView(viewModel: RecentActivityViewModel(
        backgroundManager: MLPipelineBackgroundManager.shared
    ))
    .padding()
}
