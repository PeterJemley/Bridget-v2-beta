import SwiftUI
import Charts

struct StatisticalUncertaintySectionCollapsible: View {
    let metrics: StatisticalTrainingMetrics
    @Binding var isExpanded: Bool

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            StatisticalUncertaintySection(metrics: metrics)
                .padding(.top, 8)
        } label: {
            Text("Model Uncertainty & Statistical Metrics").font(.headline)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct StatisticalUncertaintySection: View {
    let metrics: StatisticalTrainingMetrics

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                StatMiniCard(
                    title: "Accuracy 95% CI",
                    value: "\(Formatting.percentFromUnit(metrics.performanceConfidenceIntervals.accuracy95CI.lower))–\(Formatting.percentFromUnit(metrics.performanceConfidenceIntervals.accuracy95CI.upper))",
                    color: .green
                )
                StatMiniCard(
                    title: "F1 95% CI",
                    value: "\(Formatting.percentFromUnit(metrics.performanceConfidenceIntervals.f1Score95CI.lower))–\(Formatting.percentFromUnit(metrics.performanceConfidenceIntervals.f1Score95CI.upper))",
                    color: .blue
                )
                StatMiniCard(
                    title: "Mean Error 95% CI",
                    value: "\(Formatting.decimal3(metrics.performanceConfidenceIntervals.meanError95CI.lower))–\(Formatting.decimal3(metrics.performanceConfidenceIntervals.meanError95CI.upper))",
                    color: .orange
                )
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Loss Statistics")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    StatValueRow(
                        label: "Training Loss",
                        mean: metrics.trainingLossStats.mean,
                        stdDev: metrics.trainingLossStats.stdDev,
                        range: (metrics.trainingLossStats.min, metrics.trainingLossStats.max),
                        color: .teal
                    )
                    StatValueRow(
                        label: "Validation Loss",
                        mean: metrics.validationLossStats.mean,
                        stdDev: metrics.validationLossStats.stdDev,
                        range: (metrics.validationLossStats.min, metrics.validationLossStats.max),
                        color: .purple
                    )
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Prediction Error Distribution")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Chart {
                    BarMark(x: .value("Within σ", "≤1σ"), y: .value("Percent", metrics.errorDistribution.withinOneStdDev))
                        .foregroundStyle(.mint.gradient)
                    BarMark(x: .value("Within σ", "≤2σ"), y: .value("Percent", metrics.errorDistribution.withinTwoStdDev))
                        .foregroundStyle(.cyan.gradient)
                }
                .chartYAxisLabel("Percent", position: .leading)
                .frame(height: 140)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Prediction Accuracy & Variance")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    StatMiniCard(
                        title: "Accuracy Mean",
                        value: Formatting.percentFromUnit(metrics.predictionAccuracyStats.mean),
                        color: .green
                    )
                    StatMiniCard(
                        title: "Accuracy ±σ",
                        value: "±\(Formatting.percentFromUnit(metrics.predictionAccuracyStats.stdDev))",
                        color: .green.opacity(0.8)
                    )
                    StatMiniCard(
                        title: "ETA Var (σ)",
                        value: Formatting.decimal1(metrics.etaPredictionVariance.stdDev),
                        color: .indigo
                    )
                }
            }
        }
        .padding(.top, 4)
    }
}


