import SwiftUI

// MARK: - Main Dashboard View (thin composer)

struct PipelineMetricsDashboard: View {
    @State private var viewModel = PipelineMetricsViewModel()
    @State private var focusCharts = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    PipelineMetricsHeaderView(viewModel: viewModel)

                    if viewModel.isLoading {
                        ProgressView("Loading metrics...")
                            .frame(maxWidth: .infinity, minHeight: 160)
                    } else if let data = viewModel.metricsData {
                        let filtered = viewModel.filteredStages(from: data)

                        ChartsContainerView(
                            data: data,
                            chartKind: $viewModel.chartKind,
                            showAll: $viewModel.showAllStagesInCharts,
                            filteredStages: filtered,
                            focusActive: focusCharts
                        )
                        .id("chartsSection")

                        StageDetailsSectionCollapsible(
                            data: data,
                            isExpanded: $viewModel.isDetailsExpanded,
                            filteredStages: filtered
                        )

                        if let custom = data.customValidationResults, !custom.isEmpty {
                            CustomValidationSectionCollapsible(
                                results: custom,
                                isExpanded: $viewModel.isCustomValidationExpanded
                            )
                        }

                        if let stats = data.statisticalMetrics {
                            StatisticalUncertaintySectionCollapsible(
                                metrics: stats,
                                isExpanded: $viewModel.isUncertaintyExpanded
                            )
                        }
                    } else {
                        NoDataView {
                            viewModel.refreshNow()
                        }
                    }
                }
                .padding()
            }
            // Auto-scroll to charts when chart state changes
            .onChange(of: viewModel.chartKind) {
                withAnimation {
                    proxy.scrollTo("chartsSection", anchor: .top)
                }
                triggerFocusHighlight()
            }
            .onChange(of: viewModel.showAllStagesInCharts) {
                withAnimation {
                    proxy.scrollTo("chartsSection", anchor: .top)
                }
                triggerFocusHighlight()
            }
            .onChange(of: viewModel.stageFilter) {
                withAnimation {
                    proxy.scrollTo("chartsSection", anchor: .top)
                }
                triggerFocusHighlight()
            }
        }
        .refreshable { await viewModel.loadMetrics() }
        .onAppear { viewModel.onAppear() }
        .onDisappear { viewModel.onDisappear() }
    }

    private func triggerFocusHighlight() {
        focusCharts = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // ~1s
            withAnimation(.easeOut(duration: 0.3)) {
                focusCharts = false
            }
        }
    }
}

#Preview {
    PipelineMetricsDashboard()
}
