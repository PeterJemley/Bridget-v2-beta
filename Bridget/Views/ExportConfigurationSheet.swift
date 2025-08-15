import SwiftUI

public struct ExportConfigurationSheet: View {
  @Binding var selectedDate: Date
  @Binding var exportDestination: String
  let destinations: [String]
  let onExport: (Date, String) -> Void

  @Environment(\.dismiss) private var dismiss

  public var body: some View {
    NavigationStack {
      Form {
        Section("Export Configuration") {
          DatePicker("Export Date", selection: $selectedDate, displayedComponents: .date)
          Picker("Export Destination", selection: $exportDestination) {
            ForEach(destinations, id: \.self) { val in
              Text(val).tag(val)
            }
          }
        }

        Section {
          Button("Start Export") {
            onExport(selectedDate, exportDestination)
            dismiss()
          }
          .frame(maxWidth: .infinity)
          .buttonStyle(.borderedProminent)
        }
      }
      .navigationTitle("Export Configuration")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Cancel") { dismiss() }
        }
      }
    }
  }
}

#Preview {
  ExportConfigurationSheet(selectedDate: .constant(Date()),
                           exportDestination: .constant("Documents"),
                           destinations: ["Documents", "Downloads"],
                           onExport: { date, destination in
                             print("Exporting for \(date) to \(destination)")
                           })
}
