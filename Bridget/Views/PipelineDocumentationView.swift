import SwiftUI

public struct PipelineDocumentationView: View {
  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        Text("ML Pipeline Documentation")
          .font(.largeTitle)
          .bold()

        Text("Overview")
          .font(.title2)
          .bold()
        Text("""
        The ML Training Data Pipeline ingests probe tick data from various sources, organizes it by day, and exports it in NDJSON format for machine learning model training.

        This pipeline provides automated daily exports, manual data population for specific date ranges, and troubleshooting tools to ensure data readiness.

        Key features:
        - Data Availability checks for today, last week, and historical completeness.
        - Export configuration with selectable destination and date.
        - Automation with daily export scheduling and notifications.
        """)

        Text("Export Formats")
          .font(.title2)
          .bold()
        Text("""
        Exports are done in NDJSON (newline-delimited JSON) format. Each line represents a serialized ProbeTick object, suitable for streaming ingestion.

        File naming convention:
        - `minutes_YYYY-MM-DD.ndjson`, where `YYYY-MM-DD` is the export date.

        Exports can be saved either to the Documents or Downloads folder (macOS only).
        """)

        Text("Help and Support")
          .font(.title2)
          .bold()
        Text("""
        For troubleshooting, use the 'Troubleshooting' section to view logs and run health checks.

        If you encounter issues with automated exports, ensure background tasks are enabled and the chosen export time is reasonable.

        Contact support or consult the app documentation for advanced help.
        """)
      }
      .padding()
    }
    .navigationTitle("Documentation")
  }
}

#Preview {
  NavigationStack {
    PipelineDocumentationView()
  }
}
