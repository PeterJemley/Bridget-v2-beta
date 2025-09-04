import Charts
import SwiftUI

struct ChartsContainerView: View {
    let data: PipelineMetricsData
    @Binding var chartKind: PipelineMetricsViewModel.ChartKind
    @Binding var showAll: Bool
    var filteredStages: [PipelineStageMetric]? = nil
    var focusActive: Bool = false

    private var baseMetrics: [PipelineStageMetric] {
        filteredStages ?? data.stageMetrics
    }

    private var metricsForChart: [PipelineStageMetric] {
        if showAll { return baseMetrics }
        switch chartKind {
        case .performance:
            return Array(
                baseMetrics.sorted { $0.duration > $1.duration }.prefix(5)
            )
        case .memory:
            return Array(baseMetrics.sorted { $0.memory > $1.memory }.prefix(5))
        }
    }

    enum Scope: String, CaseIterable, Hashable {
        case top5 = "Top 5"
        case all = "All"
    }

    private var scopeBinding: Binding<Scope> {
        Binding<Scope>(
            get: { showAll ? .all : .top5 },
            set: { showAll = ($0 == .all) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Picker("Chart", selection: $chartKind) {
                    ForEach(
                        PipelineMetricsViewModel.ChartKind.allCases,
                        id: \.self
                    ) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("ChartKindPicker")

                Spacer()

                HStack(spacing: 8) {
                    Text("Scope")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("Scope", selection: scopeBinding) {
                        ForEach(Scope.allCases, id: \.self) { s in
                            Text(s.rawValue).tag(s)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 180)
                    .help(
                        "Choose whether to show the top 5 stages or all stages"
                    )
                }
            }

            switch chartKind {
            case .performance:
                StagePerformanceChart(metrics: metricsForChart)
            case .memory:
                MemoryUsageChart(metrics: metricsForChart)
            }
        }
        .accessibilityIdentifier("ChartsContainerView")
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    Color.accentColor.opacity(focusActive ? 0.9 : 0.0),
                    lineWidth: 3
                )
                .animation(.easeOut(duration: 0.3), value: focusActive)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(focusActive ? 0.06 : 0.0))
                .animation(.easeOut(duration: 0.3), value: focusActive)
        )
        .scaleEffect(focusActive ? 1.01 : 1.0)
        .animation(
            .spring(response: 0.35, dampingFraction: 0.9),
            value: focusActive
        )
    }
}
