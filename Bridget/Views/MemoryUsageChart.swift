import SwiftUI
import Charts

struct MemoryUsageChart: View {
    let metrics: [PipelineStageMetric]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Memory Usage")
                .font(.headline)

            Chart(metrics) { metric in
                LineMark(
                    x: .value("Stage", metric.displayName),
                    y: .value("Memory", metric.memory)
                )
                .symbol(Circle())
                .foregroundStyle(.purple.gradient)

                AreaMark(
                    x: .value("Stage", metric.displayName),
                    y: .value("Memory", metric.memory)
                )
                .foregroundStyle(.purple.opacity(0.12))
            }
            .frame(height: 220)
            .chartYAxis { AxisMarks(position: .leading) }
        }
    }
}
