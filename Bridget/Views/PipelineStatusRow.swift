import SwiftUI

public struct PipelineStatusRow: View {
  let title: String
  let subtitle: String
  let icon: String
  let color: Color

  public var body: some View {
    HStack {
      Image(systemName: icon)
        .foregroundStyle(color)
        .frame(width: 24)

      VStack(alignment: .leading, spacing: 2) {
        Text(title).font(.headline)
        Text(subtitle).font(.caption).foregroundStyle(.secondary)
      }

      Spacer()
    }
    .padding(.vertical, 2)
  }
}

#Preview {
  VStack(spacing: 12) {
    PipelineStatusRow(title: "Data Availability",
                      subtitle:
                      "Today: Available • Last Week: Available • Historical: Complete",
                      icon: "checkmark.circle.fill",
                      color: .green)

    PipelineStatusRow(title: "Last Population",
                      subtitle: "Dec 15, 2024 at 2:30 PM",
                      icon: "arrow.down.circle.fill",
                      color: .blue)

    PipelineStatusRow(title: "Last Export",
                      subtitle: "Dec 15, 2024 at 3:45 PM",
                      icon: "square.and.arrow.up.circle.fill",
                      color: .purple)

    PipelineStatusRow(title: "Error Status",
                      subtitle: "Connection failed",
                      icon: "exclamationmark.triangle.fill",
                      color: .red)
  }
  .padding()
}
