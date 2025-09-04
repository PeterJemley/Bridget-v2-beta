import Observation
import SwiftUI

struct ValidatorNameItem: Identifiable, Equatable {
    let id: String
    var name: String { id }
}

/// View for managing pipeline validation plugins
struct PipelinePluginManagementView: View {
    @Bindable var pluginManager = PipelineValidationPluginManager()
    @State private var showingAddValidator = false
    @State private var selectedValidatorName: ValidatorNameItem?
    @State private var showingConfiguration = false
    @State private var searchText = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header with controls
            headerSection

            // Search bar
            searchSection

            // Plugin list
            if pluginManager.validators.isEmpty {
                emptyStateView
            } else {
                pluginListView
            }
        }
        .navigationTitle("Validation Plugins")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingAddValidator = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddValidator) {
            AddValidatorView(pluginManager: pluginManager)
        }
        .sheet(item: $selectedValidatorName) { item in
            if let validator = pluginManager.validators.first(where: {
                $0.name == item.name
            }) {
                ValidatorConfigurationView(
                    validator: validator,
                    pluginManager: pluginManager
                )
            }
        }
        .onAppear {
            // Register built-in validators if not already registered
            if pluginManager.validators.isEmpty {
                registerBuiltInValidators()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading) {
                    // Remove large duplicate title to avoid repeating the nav title.
                    Text("Manage custom validation rules for your ML pipeline")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Toggle(
                        "Enable Plugins",
                        isOn: $pluginManager.pluginsEnabled
                    )
                    .toggleStyle(.switch)

                    Text(
                        "\(pluginManager.validators.filter { $0.isEnabled }.count) of \(pluginManager.validators.count) active"
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }

            // Plugin statistics
            HStack(spacing: 20) {
                StatCard(
                    title: "Total Plugins",
                    value: "\(pluginManager.validators.count)",
                    color: .blue
                )

                StatCard(
                    title: "Active",
                    value:
                        "\(pluginManager.validators.filter { $0.isEnabled }.count)",
                    color: .green
                )

                StatCard(
                    title: "Last Run",
                    value: pluginManager.lastValidationResults.isEmpty
                        ? "Never" : "Recent",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Search Section

    private var searchSection: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search plugins...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Plugin List View

    private var pluginListView: some View {
        List {
            ForEach(filteredValidators, id: \.name) { validator in
                PluginRowView(
                    validator: validator,
                    lastResult: pluginManager.lastValidationResults[
                        validator.name
                    ]
                ) {
                    selectedValidatorName = ValidatorNameItem(
                        id: validator.name
                    )
                }
            }
            .onDelete(perform: deleteValidator)
        }
        .listStyle(InsetGroupedListStyle())
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "puzzlepiece")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Plugins Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text(
                "Add validation plugins to enhance your pipeline's data quality checks."
            )
            .font(.body)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)

            Button("Add Plugin") {
                showingAddValidator = true
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helper Methods

    private var filteredValidators: [PipelineValidator] {
        if searchText.isEmpty {
            return pluginManager.validators
        } else {
            return pluginManager.validators.filter { validator in
                validator.name.localizedCaseInsensitiveContains(searchText)
                    || validator.description.localizedCaseInsensitiveContains(
                        searchText
                    )
            }
        }
    }

    private func deleteValidator(at offsets: IndexSet) {
        for index in offsets {
            let validator = filteredValidators[index]
            pluginManager.unregisterValidator(named: validator.name)
        }
    }

    private func registerBuiltInValidators() {
        pluginManager.registerValidator(NoMissingGateAnomValidator())
        pluginManager.registerValidator(DetourDeltaRangeValidator())
        pluginManager.registerValidator(DataQualityValidator())
    }
}

// MARK: - Plugin Row View

struct PluginRowView: View {
    let validator: PipelineValidator
    let lastResult: DataValidationResult?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                // Plugin info
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(validator.name)
                            .font(.headline)
                            .foregroundColor(.primary)

                        Spacer()

                        Text("Priority \(validator.priority)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color(.systemGray5))
                            .cornerRadius(4)
                    }

                    Text(validator.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    // Last result summary
                    if let result = lastResult {
                        HStack(spacing: 8) {
                            Image(
                                systemName: result.isValid
                                    ? "checkmark.circle.fill"
                                    : "xmark.circle.fill"
                            )
                            .foregroundColor(result.isValid ? .green : .red)
                            .font(.caption)

                            Text(result.isValid ? "Passed" : "Failed")
                                .font(.caption)
                                .foregroundColor(result.isValid ? .green : .red)

                            if !result.errors.isEmpty {
                                Text("• \(result.errors.count) errors")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }

                            if !result.warnings.isEmpty {
                                Text("• \(result.warnings.count) warnings")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else {
                        Text("Not run yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Enable/disable toggle
                Toggle(
                    "",
                    isOn: Binding(
                        get: { validator.isEnabled },
                        set: { _ in
                            // Update validator enabled state
                            // Note: This would need to be implemented in the validator protocol
                            // For now, the toggle is read-only
                        }
                    )
                )
                .toggleStyle(.switch)
                .scaleEffect(0.8)

                // Chevron
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var statusColor: Color {
        if !validator.isEnabled {
            return .gray
        } else if let result = lastResult {
            return result.isValid ? .green : .red
        } else {
            return .blue
        }
    }
}

// MARK: - Stat Card View

struct StatCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 1)
    }
}

// MARK: - Add Validator View

struct AddValidatorView: View {
    @Bindable var pluginManager: PipelineValidationPluginManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedValidatorType = "NoMissingGateAnom"
    @State private var customName = ""
    @State private var customDescription = ""
    @State private var priority = 100

    private let availableValidatorTypes = [
        "NoMissingGateAnom": "No Missing Gate Anomaly",
        "DetourDeltaRange": "Detour Delta Range",
        "DataQuality": "Data Quality",
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Validator Type") {
                    Picker("Type", selection: $selectedValidatorType) {
                        ForEach(
                            Array(availableValidatorTypes.keys.sorted()),
                            id: \.self
                        ) { key in
                            Text(availableValidatorTypes[key] ?? key).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Configuration") {
                    TextField("Name", text: $customName)
                    TextField("Description", text: $customDescription)

                    Stepper(
                        "Priority: \(priority)",
                        value: $priority,
                        in: 1...1000
                    )
                }

                Section("Preview") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(
                            "Name: \(customName.isEmpty ? selectedValidatorType : customName)"
                        )
                        .font(.subheadline)

                        Text(
                            "Description: \(customDescription.isEmpty ? availableValidatorTypes[selectedValidatorType] ?? "" : customDescription)"
                        )
                        .font(.subheadline)

                        Text("Priority: \(priority)")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Validator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addValidator()
                    }
                    .disabled(customName.isEmpty)
                }
            }
        }
        .onAppear {
            customName = selectedValidatorType
            customDescription =
                availableValidatorTypes[selectedValidatorType] ?? ""
        }
        .onChange(of: selectedValidatorType) {
            customName = selectedValidatorType
            customDescription =
                availableValidatorTypes[selectedValidatorType] ?? ""
        }
    }

    private func addValidator() {
        let validator: PipelineValidator

        switch selectedValidatorType {
        case "NoMissingGateAnom":
            validator = NoMissingGateAnomValidator()
        case "DetourDeltaRange":
            validator = DetourDeltaRangeValidator()
        case "DataQuality":
            validator = DataQualityValidator()
        default:
            return
        }

        // Update validator properties
        if let mutableValidator = validator as? MutableValidator {
            mutableValidator.updateName(customName)
            mutableValidator.updateDescription(customDescription)
            mutableValidator.updatePriority(priority)
        }

        pluginManager.registerValidator(validator)
        dismiss()
    }
}

// MARK: - Validator Configuration View

struct ValidatorConfigurationView: View {
    let validator: PipelineValidator
    @Bindable var pluginManager: PipelineValidationPluginManager
    @Environment(\.dismiss) private var dismiss

    @State private var configuration: [String: Any] = [:]
    @State private var showingAlert = false
    @State private var alertMessage = ""

    var body: some View {
        NavigationView {
            Form {
                validatorInfoSection
                configurationSection
                lastResultsSection
                actionsSection
            }
            .navigationTitle("Validator Configuration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            configuration = validator.getConfiguration()
        }
        .alert("Configuration Error", isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
    }

    private var validatorInfoSection: some View {
        Section("Validator Info") {
            HStack {
                Text("Name")
                Spacer()
                Text(validator.name)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Description")
                Spacer()
                Text(validator.description)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.trailing)
            }

            HStack {
                Text("Priority")
                Spacer()
                Text("\(validator.priority)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Status")
                Spacer()
                Text(validator.isEnabled ? "Enabled" : "Disabled")
                    .foregroundColor(validator.isEnabled ? .green : .red)
            }
        }
    }

    private var configurationSection: some View {
        Section("Configuration") {
            ForEach(Array(configuration.keys.sorted()), id: \.self) { key in
                if let value = configuration[key] {
                    HStack {
                        Text(key)
                        Spacer()
                        Text("\(String(describing: value))")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }

    private var lastResultsSection: some View {
        Section("Last Results") {
            if let result = pluginManager.lastValidationResults[validator.name]
            {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(
                            systemName: result.isValid
                                ? "checkmark.circle.fill" : "xmark.circle.fill"
                        )
                        .foregroundColor(result.isValid ? .green : .red)

                        Text(result.isValid ? "Passed" : "Failed")
                            .fontWeight(.semibold)
                            .foregroundColor(result.isValid ? .green : .red)
                    }

                    if !result.errors.isEmpty {
                        Text("Errors: \(result.errors.joined(separator: "; "))")
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if !result.warnings.isEmpty {
                        Text(
                            "Warnings: \(result.warnings.joined(separator: "; "))"
                        )
                        .font(.caption)
                        .foregroundColor(.orange)
                    }
                }
            } else {
                Text("No results available")
                    .foregroundColor(.secondary)
            }
        }
    }

    private var actionsSection: some View {
        Section("Actions") {
            Button(validator.isEnabled ? "Disable" : "Enable") {
                pluginManager.setValidator(
                    validator.name,
                    enabled: !validator.isEnabled
                )
            }
            .foregroundColor(validator.isEnabled ? .red : .green)

            Button("Delete") {
                pluginManager.unregisterValidator(named: validator.name)
                dismiss()
            }
            .foregroundColor(.red)
        }
    }
}

// MARK: - Supporting Protocols

protocol MutableValidator {
    func updateName(_ name: String)
    func updateDescription(_ description: String)
    func updatePriority(_ priority: Int)
}

// MARK: - Preview

#Preview {
    PipelinePluginManagementView()
}
