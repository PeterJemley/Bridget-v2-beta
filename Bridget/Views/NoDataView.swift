import SwiftUI

struct NoDataView: View {
    var onRefresh: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.bar.doc.horizontal")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Metrics Available")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Run the pipeline to generate metrics, or check the metrics file path.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Refresh") { onRefresh() }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .padding()
    }
}
