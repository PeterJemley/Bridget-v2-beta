import SwiftUI

struct BridgeStatusView: View {
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          // Bridge Status Overview
          VStack(alignment: .leading, spacing: 12) {
            Text("Bridge Status Overview")
              .font(.title2)
              .bold()

            // Sample bridge status cards
            BridgeStatusCard(bridgeName: "Fremont Bridge",
                             status: "Open",
                             statusColor: .green,
                             lastUpdated: "2 minutes ago")

            BridgeStatusCard(bridgeName: "Ballard Bridge",
                             status: "Opening",
                             statusColor: .orange,
                             lastUpdated: "1 minute ago")

            BridgeStatusCard(bridgeName: "University Bridge",
                             status: "Closed",
                             statusColor: .red,
                             lastUpdated: "5 minutes ago")
          }
          .padding()
        }
      }
      .navigationTitle("Bridge Status")
      .navigationBarTitleDisplayMode(.large)
      .toolbar {
        ToolbarItem(placement: .topBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }
}

struct BridgeStatusCard: View {
  let bridgeName: String
  let status: String
  let statusColor: Color
  let lastUpdated: String

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(bridgeName)
          .font(.headline)
        Text("Last updated: \(lastUpdated)")
          .font(.caption)
          .foregroundStyle(.secondary)
      }

      Spacer()

      VStack(alignment: .trailing, spacing: 4) {
        Text(status)
          .font(.headline)
          .foregroundStyle(statusColor)
        Text("Status")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
    .padding()
    .background(Color(.systemGray6))
    .cornerRadius(12)
  }
}

#Preview {
  BridgeStatusView()
}



