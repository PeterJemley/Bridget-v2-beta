import Observation
import SwiftData
import SwiftUI

// MARK: - Traffic Profile Management View

@Observable
final class TrafficProfileManagementViewModel {
    private let modelContext: ModelContext
    private let provider: BasicTrafficProfileProvider

    var profiles: [TrafficProfile] = []
    var selectedProfile: TrafficProfile?
    var showingCreateProfile = false
    var showingEditProfile = false

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.provider = BasicTrafficProfileProvider(modelContext: modelContext)
        loadProfiles()
    }

    func loadProfiles() {
        profiles = provider.getAllProfiles()
        selectedProfile = provider.getActiveProfile()
    }

    func createProfile(name: String, description: String) {
        _ = provider.createProfile(
            name: name,
            profileDescription: description
        )
        loadProfiles()
    }

    func setActiveProfile(_ profile: TrafficProfile) {
        provider.setActiveProfile(profile)
        selectedProfile = profile
    }

    func deleteProfile(_ profile: TrafficProfile) {
        provider.deleteProfile(profile)
        loadProfiles()
    }
}

struct TrafficProfileManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: TrafficProfileManagementViewModel
    @Environment(\.dismiss) private var dismiss

    init(modelContext: ModelContext) {
        self._viewModel = State(
            initialValue: TrafficProfileManagementViewModel(
                modelContext: modelContext
            )
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Active Profile") {
                    if let activeProfile = viewModel.selectedProfile {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(activeProfile.name)
                                    .font(.headline)
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            }

                            if !activeProfile.profileDescription.isEmpty {
                                Text(activeProfile.profileDescription)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            TrafficProfileSummaryView(profile: activeProfile)
                        }
                        .padding(.vertical, 4)
                    } else {
                        Text("No active profile")
                            .foregroundColor(.secondary)
                    }
                }

                Section("All Profiles") {
                    ForEach(viewModel.profiles) { profile in
                        TrafficProfileRowView(
                            profile: profile,
                            isActive: profile.id
                                == viewModel.selectedProfile?.id,
                            onActivate: { viewModel.setActiveProfile(profile) },
                            onDelete: { viewModel.deleteProfile(profile) }
                        )
                    }
                }
            }
            .navigationTitle("Traffic Profiles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add Profile") {
                        viewModel.showingCreateProfile = true
                    }
                }
            }
            .sheet(isPresented: $viewModel.showingCreateProfile) {
                CreateTrafficProfileView { name, description in
                    viewModel.createProfile(
                        name: name,
                        description: description
                    )
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct TrafficProfileRowView: View {
    let profile: TrafficProfile
    let isActive: Bool
    let onActivate: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.headline)

                if !profile.profileDescription.isEmpty {
                    Text(profile.profileDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Activate") {
                    onActivate()
                }
                .buttonStyle(.bordered)
            }

            Button("Delete") {
                onDelete()
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.vertical, 4)
    }
}

struct TrafficProfileSummaryView: View {
    let profile: TrafficProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time-of-Day Multipliers")
                .font(.caption)
                .fontWeight(.medium)

            HStack {
                MultiplierView(
                    label: "Morning",
                    value: profile.morningRushMultiplier
                )
                MultiplierView(label: "Midday", value: profile.middayMultiplier)
                MultiplierView(
                    label: "Evening",
                    value: profile.eveningRushMultiplier
                )
                MultiplierView(label: "Night", value: profile.nightMultiplier)
            }

            HStack {
                MultiplierView(
                    label: "Weekday",
                    value: profile.weekdayMultiplier
                )
                MultiplierView(
                    label: "Weekend",
                    value: profile.weekendMultiplier
                )
            }
        }
    }
}

struct MultiplierView: View {
    let label: String
    let value: Double

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(String(format: "%.1fx", value))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(multiplierColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var multiplierColor: Color {
        if value < 0.8 { return .green }
        if value < 1.2 { return .blue }
        if value < 1.8 { return .orange }
        return .red
    }
}

struct CreateTrafficProfileView: View {
    let onCreate: (String, String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile Details") {
                    TextField("Profile Name", text: $name)
                    TextField(
                        "Description (Optional)",
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(3...6)
                }

                Section("Default Multipliers") {
                    Text(
                        "This will create a profile with default Seattle traffic patterns:"
                    )
                    Text("• Morning Rush (7-9 AM): 1.5x")
                    Text("• Midday (9 AM-4 PM): 1.0x")
                    Text("• Evening Rush (4-7 PM): 1.8x")
                    Text("• Night (7 PM-7 AM): 0.8x")
                    Text("• Weekday: 1.0x")
                    Text("• Weekend: 0.9x")
                }
            }
            .navigationTitle("New Traffic Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        onCreate(name, description)
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
        }
    }
}

#Preview {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
        for: TrafficProfile.self,
        configurations: config
    )

    return TrafficProfileManagementView(modelContext: container.mainContext)
}
