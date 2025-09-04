import SwiftData
import SwiftUI

struct MLPipelineTabView: View {
    @Bindable var viewModel: MLPipelineViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                headerView

                if viewModel.isTraining {
                    trainingProgressView
                }

                trainingControlsView

                if !viewModel.trainedModels.isEmpty {
                    trainedModelsView
                }

                if let error = viewModel.trainingError {
                    errorView(error: error)
                }

                Spacer(minLength: 0)
            }
            .padding()
        }
        // Navigation title is applied by the presenting NavigationStack in Settings.
    }

    private var headerView: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Core ML Training Pipeline")
                .font(.title2.bold())
                .foregroundColor(.primary)

            Text("Train bridge lift prediction models using on-device Core ML")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var trainingProgressView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gear.circle.fill")
                    .foregroundColor(.blue)
                Text("Training in Progress")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text(viewModel.trainingStatus)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                ProgressView(value: viewModel.trainingProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)

                Text("\(Int(viewModel.trainingProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var trainingControlsView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "play.circle.fill")
                    .foregroundColor(.green)
                Text("Training Controls")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: 12) {
                Button(action: { startFullPipeline() }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Start Full Training Pipeline")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .disabled(viewModel.isTraining)

                Text("Train models for all horizons (0, 3, 6, 9, 12 minutes)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Text("Individual Horizon Training")
                    .font(.subheadline.bold())

                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 8
                ) {
                    ForEach(defaultHorizons, id: \.self) { horizon in
                        Button(action: {
                            startSingleHorizonTraining(horizon: horizon)
                        }) {
                            Text("\(horizon) min")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(6)
                        }
                        .disabled(viewModel.isTraining)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var trainedModelsView: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Trained Models")
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(
                    Array(viewModel.trainedModels.keys.sorted()),
                    id: \.self
                ) { horizon in
                    if let modelPath = viewModel.trainedModels[horizon] {
                        HStack {
                            Text("\(horizon)-min horizon:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(
                                modelPath.components(separatedBy: "/").last
                                    ?? "Unknown"
                            )
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func errorView(error: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                Text("Training Error")
                    .font(.headline)
                Spacer()
            }

            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)

            Button("Retry") {
                viewModel.trainingError = nil
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color.red)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.red.opacity(0.1))
        .cornerRadius(12)
    }

    // MARK: - Training Actions

    private func startFullPipeline() {
        let sampleNDJSONPath = "/path/to/sample_data.ndjson"
        let outputDirectory = FileManagerUtils.temporaryDirectory().path

        viewModel.startTrainingPipeline(
            ndjsonPath: sampleNDJSONPath,
            outputDirectory: outputDirectory
        )
    }

    private func startSingleHorizonTraining(horizon: Int) {
        let sampleCSVPath = "/path/to/training_data_horizon_\(horizon).csv"
        let outputDirectory = FileManagerUtils.temporaryDirectory().path

        viewModel.startSingleHorizonTraining(
            csvPath: sampleCSVPath,
            horizon: horizon,
            outputDirectory: outputDirectory
        )
    }
}

#Preview("ML Pipeline Tab View") {
    let modelContext = try! ModelContainer(for: BridgeEvent.self).mainContext
    let viewModel = MLPipelineViewModel(modelContext: modelContext)

    // Preview without nested navigation; title is provided by parent in app.
    MLPipelineTabView(viewModel: viewModel)
        .padding()
}
