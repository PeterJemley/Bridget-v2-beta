import SwiftUI

struct RouteListView: View {
  @Bindable var appState: AppState

  var body: some View {
    VStack {
      // Validation failures display
      if appState.hasValidationFailures {
        VStack(alignment: .leading, spacing: 6) {
          HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.yellow)
            Text("Some records were skipped due to data validation errors.")
              .font(.footnote)
              .foregroundColor(.secondary)
          }
          .padding(.bottom, 2)
          ForEach(appState.validationFailures.prefix(5), id: \.reason.description) { failure in
            Text("• \(failure.reason.description)")
              .font(.caption2)
              .foregroundColor(.orange)
              .lineLimit(1)
              .truncationMode(.tail)
          }
          if appState.validationFailures.count > 5 {
            Text("...and \(appState.validationFailures.count - 5) more")
              .font(.caption2)
              .foregroundColor(.secondary)
          }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(10)
        .padding([.horizontal, .top])
      }

      // Rest of RouteListView UI below...
      List(appState.routes) { route in
        RouteRow(route: route)
      }
    }
  }
}

// Assuming types used here for context
@Observable
final class AppState {
  var validationFailures: [ValidationFailure] = []
  var routes: [Route] = []

  var hasValidationFailures: Bool {
    !validationFailures.isEmpty
  }
}

struct ValidationFailure: Identifiable {
  let id = UUID()
  let reason: ValidationReason
}

struct ValidationReason: CustomStringConvertible {
  let description: String
}

struct Route: Identifiable {
  let id: String
  // route properties
}

struct RouteRow: View {
  let route: Route
  var body: some View {
    Text(route.id)
  }
}
