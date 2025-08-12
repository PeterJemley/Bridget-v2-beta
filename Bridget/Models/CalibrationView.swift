import SwiftUI

struct CalibrationView: View {
  @Bindable var vm: CalibrationVM

  var body: some View {
    VStack(spacing: 16) {
      HStack {
        Text("Bridge Calibration")
          .font(.title2).bold()
        Spacer()
        ProgressView(value: vm.isRunning ? vm.overallProgress : 0, total: 1)
          .frame(width: 120)
      }

      List {
        ForEach(Array(vm.rows.enumerated()), id: \.element.id) { _, row in
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(row.name).font(.headline)
              if let d = row.lastValidated {
                Text("Last validated \(d.formatted(date: .abbreviated, time: .shortened))")
                  .font(.caption).foregroundStyle(.secondary)
              }
              if !row.qualityText.isEmpty {
                Text(row.qualityText).font(.caption2).monospaced().foregroundStyle(.secondary)
              }
            }
            Spacer()
            switch row.state {
            case .pending: Image(systemName: "clock").foregroundStyle(.secondary)
            case .running: ProgressView().controlSize(.small)
            case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            case .error:   Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            }
          }
          .contentShape(Rectangle())
        }
      }
      .listStyle(.insetGrouped)

      HStack {
        Button("Recalibrate All") {
          vm.start(force: true)
        }
        .buttonStyle(.borderedProminent)
        .disabled(vm.isRunning)

        Button("Close") { /* dismiss */ }
          .buttonStyle(.bordered)
      }
    }
    .padding()
  }
}
