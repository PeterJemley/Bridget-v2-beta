import SwiftUI

struct PipelineMetricsHeaderView: View {
    @Bindable var viewModel: PipelineMetricsViewModel
    @State private var showAutoRefreshInfo = false
    @Environment(\.horizontalSizeClass) private var hSizeClass

    private var isCompact: Bool { hSizeClass == .compact }
    private var autoLabelText: String {
        isCompact ? "Auto (30s)" : "Auto-refresh (30s)"
    }

    var body: some View {
        VStack(spacing: 12) {
            ViewThatFits {
                headerRow
                VStack(alignment: .leading, spacing: 10) {
                    titleBlock
                    controlsRow
                }
            }
            .accessibilityIdentifier("PipelineMetricsHeaderView")

            HStack {
                Picker("Time Range", selection: $viewModel.selectedTimeRange) {
                    ForEach(
                        PipelineMetricsViewModel.TimeRange.allCases,
                        id: \.self
                    ) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(isCompact ? .small : .regular)
                .accessibilityIdentifier("TimeRangePicker")

                Spacer()

                if viewModel.stageFilter != .none {
                    HStack(spacing: 6) {
                        Image(
                            systemName: "line.3.horizontal.decrease.circle.fill"
                        )
                        .foregroundStyle(.orange)
                        Text("Filter: \(viewModel.stageFilter.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button {
                            viewModel.clearFilters()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .help("Clear stage filter")
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .clipShape(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                }
            }

            if let data = viewModel.metricsData {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 180), spacing: 12)],
                    spacing: 12
                ) {
                    MetricCard(
                        title: "Total Duration",
                        value: Formatting.seconds(data.totalDuration),
                        color: .blue,
                        iconSystemName: "timer",
                        subtitle: viewModel.showAllStagesInCharts
                            ? "All stages" : "Top 5 shown",
                        accessoryText: "sec",
                        action: {
                            viewModel.chartKind = .performance
                            viewModel.showAllStagesInCharts = false
                        },
                        provideHapticOnTap: true
                    )
                    .contextMenu {
                        Button {
                            viewModel.chartKind = .performance
                        } label: {
                            Label(
                                "Go to Performance chart",
                                systemImage: "chart.bar.fill"
                            )
                        }
                        Divider()
                        Button {
                            viewModel.showAllStagesInCharts = false
                        } label: {
                            Label(
                                "Scope: Top 5",
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                        }
                        Button {
                            viewModel.showAllStagesInCharts = true
                        } label: {
                            Label(
                                "Scope: All",
                                systemImage: "square.stack.3d.up.fill"
                            )
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            viewModel.showAllStagesInCharts.toggle()
                            #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium)
                                    .impactOccurred()
                            #endif
                        }
                    )

                    MetricCard(
                        title: "Total Memory",
                        value: Formatting.memoryMB(data.totalMemory),
                        color: .purple,
                        iconSystemName: "memorychip",
                        subtitle: viewModel.showAllStagesInCharts
                            ? "All stages" : "Top 5 shown",
                        accessoryText: "MB",
                        action: {
                            viewModel.chartKind = .memory
                            viewModel.showAllStagesInCharts = false
                        },
                        provideHapticOnTap: true
                    )
                    .contextMenu {
                        Button {
                            viewModel.chartKind = .memory
                        } label: {
                            Label(
                                "Go to Memory chart",
                                systemImage: "waveform.path.ecg.rectangle"
                            )
                        }
                        Divider()
                        Button {
                            viewModel.showAllStagesInCharts = false
                        } label: {
                            Label(
                                "Scope: Top 5",
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                        }
                        Button {
                            viewModel.showAllStagesInCharts = true
                        } label: {
                            Label(
                                "Scope: All",
                                systemImage: "square.stack.3d.up.fill"
                            )
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            viewModel.showAllStagesInCharts.toggle()
                            #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium)
                                    .impactOccurred()
                            #endif
                        }
                    )

                    MetricCard(
                        title: "Success Rate",
                        value: Formatting.percentFromUnit(
                            data.averageValidationRate
                        ),
                        color: .green,
                        iconSystemName: "checkmark.seal.fill",
                        subtitle: viewModel.stageFilter == .problematicOnly
                            ? "Showing problematic"
                            : "Validation across stages",
                        accessoryText: data.averageValidationRate
                            < viewModel.validationWarningThreshold
                            ? "Low" : "OK",
                        action: {
                            if let results = viewModel.metricsData?
                                .customValidationResults, !results.isEmpty
                            {
                                viewModel.isCustomValidationExpanded = true
                            } else {
                                viewModel.isDetailsExpanded = true
                            }
                        },
                        provideHapticOnTap: true
                    )
                    .contextMenu {
                        Button {
                            viewModel.toggleProblematicFilter()
                        } label: {
                            Label(
                                "Toggle Problematic Filter",
                                systemImage: "line.3.horizontal.decrease.circle"
                            )
                        }
                        if viewModel.stageFilter != .none {
                            Button(role: .destructive) {
                                viewModel.clearFilters()
                            } label: {
                                Label(
                                    "Clear Filter",
                                    systemImage: "xmark.circle.fill"
                                )
                            }
                        }
                    }
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.4).onEnded { _ in
                            viewModel.toggleProblematicFilter()
                            #if canImport(UIKit)
                                UIImpactFeedbackGenerator(style: .medium)
                                    .impactOccurred()
                            #endif
                        }
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Pipeline Performance Dashboard")
                .font(.title3).fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .layoutPriority(1)
                .accessibilityIdentifier("Pipeline Metrics Dashboard")
            if let data = viewModel.metricsData {
                Text("Last updated: \(data.timestamp, style: .relative)")
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private var controlsRow: some View {
        HStack(spacing: 8) {
            Button("Refresh Now") { viewModel.refreshNow() }
                .buttonStyle(.bordered)
                .controlSize(isCompact ? .small : .regular)
                .accessibilityIdentifier("RefreshButton")

            Toggle(
                isOn: .init(
                    get: { viewModel.autoRefresh },
                    set: { viewModel.toggleAutoRefresh($0) }
                )
            ) {
                Text(autoLabelText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .toggleStyle(.switch)
            .controlSize(isCompact ? .small : .regular)

            Button {
                showAutoRefreshInfo = true
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .controlSize(isCompact ? .small : .regular)
            .popover(isPresented: $showAutoRefreshInfo) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Auto-refresh").font(.headline)
                    Text(
                        "When enabled, this dashboard refreshes metrics every 30 seconds. You can also use \"Refresh Now\" at any time."
                    )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    Divider()
                    Text(
                        "Tip: Long-press cards for quick actions, or use the chart Scope to switch Top 5 vs All."
                    )
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    HStack {
                        Spacer()
                        Button("Close") { showAutoRefreshInfo = false }
                            .buttonStyle(.borderedProminent)
                    }
                }
                .padding()
                .frame(maxWidth: 380)
            }
            .help("What does auto-refresh do?")
        }
    }

    private var headerRow: some View {
        HStack(alignment: .firstTextBaseline) {
            titleBlock
            Spacer()
            controlsRow
                .layoutPriority(2)
        }
    }
}
