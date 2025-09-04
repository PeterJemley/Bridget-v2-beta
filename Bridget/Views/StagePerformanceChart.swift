import Charts
import SwiftUI

struct StagePerformanceChart: View {
    let metrics: [PipelineStageMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stage Performance")
                .font(.headline)

            Chart(metrics) { metric in
                BarMark(
                    x: .value("Stage", metric.displayName),
                    y: .value("Duration (s)", metric.duration)
                )
                .foregroundStyle(.blue.gradient)
                .annotation(position: .top, alignment: .center) {
                    Text(Formatting.seconds(metric.duration))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(height: 220)
            .chartYAxis { AxisMarks(position: .leading) }
        }
        .accessibilityIdentifier("StagePerformanceChart")
    }
}
