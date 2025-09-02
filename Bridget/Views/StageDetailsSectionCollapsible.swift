import SwiftUI

struct StageDetailsSectionCollapsible: View {
    let data: PipelineMetricsData
    @Binding var isExpanded: Bool
    var filteredStages: [PipelineStageMetric]? = nil

    private var baseMetrics: [PipelineStageMetric] {
        filteredStages ?? data.stageMetrics
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            LazyVStack(spacing: 8) {
                ForEach(baseMetrics) { metric in
                    StageDetailRowCollapsible(metric: metric)
                }
            }
            .padding(.top, 8)
        } label: {
            HStack {
                Text("Stage Details").font(.headline)
                Spacer()
                Text("\(baseMetrics.count) \(baseMetrics.count == 1 ? "stage" : "stages")")
                    .font(.caption).foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct StageDetailRowCollapsible: View {
    let metric: PipelineStageMetric
    @State private var showAllChips = false

    private var chips: [(icon: String, text: String, color: Color, foreground: Color)] {
        [
            ("timer", Formatting.seconds(metric.duration), Color.gray.opacity(0.12), .secondary),
            ("memorychip", Formatting.memoryMB(metric.memory), Color.gray.opacity(0.12), .secondary),
            ("exclamationmark.triangle", "\(Formatting.integer(metric.errorCount)) errors",
             metric.errorCount > 0 ? .red.opacity(0.15) : Color.gray.opacity(0.12),
             metric.errorCount > 0 ? .red : .secondary),
            ("person.3", "\(Formatting.integer(metric.recordCount)) records", Color.gray.opacity(0.12), .secondary),
            ("checkmark.seal", Formatting.percentFromUnit(metric.validationRate), Color.gray.opacity(0.12), .secondary),
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(metric.displayName)
                    .font(.subheadline).fontWeight(.semibold)
                Spacer()
                statusBadge
            }

            let inline = Array(chips.prefix(3))
            let overflow = Array(chips.dropFirst(3))

            HStack(spacing: 8) {
                ForEach(Array(inline.enumerated()), id: \.offset) { _, chip in
                    infoChip(icon: chip.icon, text: chip.text, color: chip.color, foreground: chip.foreground)
                }

                if !overflow.isEmpty {
                    Button("+\(overflow.count) more") { showAllChips = true }
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.12))
                        .cornerRadius(6)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
        .sheet(isPresented: $showAllChips) {
            VStack(alignment: .leading, spacing: 12) {
                Text(metric.displayName).font(.headline)
                ForEach(Array(chips.enumerated()), id: \.offset) { _, chip in
                    infoChip(icon: chip.icon, text: chip.text, color: chip.color, foreground: chip.foreground)
                }
                Spacer()
                Button("Close") { showAllChips = false }
                    .buttonStyle(.borderedProminent)
            }
            .padding()
            .presentationDetents([.medium])
        }
    }

    private var statusBadge: some View {
        Text(metric.errorCount > 0 ? "Issues" : (metric.validationRate < 0.95 ? "Warning" : "OK"))
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(metric.statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(metric.statusColor.opacity(0.12))
            .cornerRadius(6)
    }

    private func infoChip(icon: String, text: String, color: Color = Color.gray.opacity(0.12), foreground: Color = .secondary) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundColor(foreground)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(color)
        .cornerRadius(6)
    }
}
