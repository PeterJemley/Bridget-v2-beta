import SwiftUI

struct PipelineSettingsView: View {
  @Bindable var settingsViewModel: SettingsViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      // Automation Settings
      VStack(alignment: .leading, spacing: 8) {
        Text("Automation Settings")
          .font(.headline)

        Toggle("Auto Export",
               isOn: $settingsViewModel.autoExportEnabled)

        if settingsViewModel.autoExportEnabled {
          HStack {
            Text("Export Time:")
            Button(settingsViewModel.autoExportTime) {
              settingsViewModel.showingTimePicker = true
            }
            .buttonStyle(.bordered)
          }
        }
      }

      // Notification Settings
      VStack(alignment: .leading, spacing: 8) {
        Text("Notifications")
          .font(.headline)

        Toggle("Enable Notifications",
               isOn: $settingsViewModel.notificationsEnabled)

        if settingsViewModel.notificationsEnabled {
          Toggle("Success Notifications",
                 isOn: $settingsViewModel.successNotifications)
          Toggle("Failure Notifications",
                 isOn: $settingsViewModel.failureNotifications)
          Toggle("Progress Notifications",
                 isOn: $settingsViewModel.progressNotifications)
          Toggle("Health Notifications",
                 isOn: $settingsViewModel.healthNotifications)
        }
      }

      // Actions
      VStack(spacing: 8) {
        Button("Apply Settings") {
          settingsViewModel.configureNotifications()
          settingsViewModel.scheduleAutoExport()
        }
        .buttonStyle(.bordered)
      }
    }
    .padding()
    .sheet(isPresented: $settingsViewModel.showingTimePicker) {
      NavigationStack {
        VStack {
          DatePicker("Export Time",
                     selection: $settingsViewModel.tempTime,
                     displayedComponents: .hourAndMinute)
            .datePickerStyle(.wheel)
            .padding()
        }
        .navigationTitle("Set Export Time")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .confirmationAction) {
            Button("Done") {
              let formatter = DateFormatter()
              formatter.dateFormat = "HH:mm"
              settingsViewModel.autoExportTime = formatter.string(
                from: settingsViewModel.tempTime
              )
              settingsViewModel.showingTimePicker = false
            }
          }
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              settingsViewModel.showingTimePicker = false
            }
          }
        }
      }
      .presentationDetents([.medium])
    }
  }
}

#Preview {
  PipelineSettingsView(settingsViewModel: SettingsViewModel())
}
