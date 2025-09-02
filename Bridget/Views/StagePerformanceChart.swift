import SwiftUI
import Charts

struct StagePerformanceChart: View {
    let metrics: [PipelineStageMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stage Performance")
                .font(.headline)

            Chart(metrics) { metric in
                BarMark(
                    x: .value("Duration", metric.duration),
                    y: .value("Stage", metric.displayName)
                )
                .foregroundStyle(metric.statusColor.gradient)
            }
            .frame(height: 220)
            .chartXAxis { AxisMarks(position: .bottom) }
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }
}
