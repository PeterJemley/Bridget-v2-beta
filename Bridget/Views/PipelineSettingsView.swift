import SwiftUI

struct PipelineSettingsView: View {
  @Bindable var settingsViewModel: SettingsViewModel
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    Group {
      // Automation Settings
      Section("Automation") {
        Toggle("Auto Export",
               isOn: $settingsViewModel.autoExportEnabled)

        if settingsViewModel.autoExportEnabled {
          HStack {
            Text("Export Time")
            Spacer()
            Button(settingsViewModel.autoExportTime) {
              settingsViewModel.showingTimePicker = true
            }
            .buttonStyle(.bordered)
          }
        }
      }

      // Notification Settings
      Section("Notifications") {
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
      Section {
        Button("Apply Settings") {
          settingsViewModel.configureNotifications()
          settingsViewModel.scheduleAutoExport()
        }
      }
    }
    // Present time picker as a sheet
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
  // Embed in a List to preview system Settings styling
  List {
    PipelineSettingsView(settingsViewModel: SettingsViewModel())
  }
  .listStyle(.insetGrouped)
}
