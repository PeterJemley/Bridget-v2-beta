import SwiftUI

struct TrafficAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Traffic Alerts Overview
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Current Traffic Alerts")
                            .font(.title2)
                            .bold()
                        
                        // Sample traffic alert cards
                        TrafficAlertCard(
                            title: "Fremont Bridge Delay",
                            description: "Bridge opening in progress. Expect 5-10 minute delay.",
                            severity: .moderate,
                            location: "Fremont Bridge",
                            timeAgo: "3 minutes ago"
                        )
                        
                        TrafficAlertCard(
                            title: "Ballard Bridge Maintenance",
                            description: "Scheduled maintenance causing lane closures.",
                            severity: .minor,
                            location: "Ballard Bridge",
                            timeAgo: "15 minutes ago"
                        )
                        
                        TrafficAlertCard(
                            title: "University Bridge Incident",
                            description: "Vehicle breakdown blocking right lane.",
                            severity: .major,
                            location: "University Bridge",
                            timeAgo: "8 minutes ago"
                        )
                    }
                    .padding()
                }
            }
            .navigationTitle("Traffic Alerts")
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

struct TrafficAlertCard: View {
    let title: String
    let description: String
    let severity: AlertSeverity
    let location: String
    let timeAgo: String
    
    enum AlertSeverity {
        case minor, moderate, major
        
        var color: Color {
            switch self {
            case .minor: return .green
            case .moderate: return .orange
            case .major: return .red
            }
        }
        
        var icon: String {
            switch self {
            case .minor: return "info.circle.fill"
            case .moderate: return "exclamationmark.triangle.fill"
            case .major: return "exclamationmark.octagon.fill"
            }
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: severity.icon)
                    .foregroundStyle(severity.color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(timeAgo)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Text(description)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            HStack {
                Image(systemName: "location.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(location)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

#Preview {
    TrafficAlertsView()
}

