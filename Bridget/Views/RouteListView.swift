//
//  RouteListView.swift
//  Bridget
//
//  ## Purpose
//  UI layer for displaying historical bridge opening data with error handling
//
//  ## Dependencies
//  SwiftUI framework, AppStateModel (via @Bindable)
//
//  ## Integration Points
//  Displays historical bridge opening data from AppStateModel
//  Shows loading states during historical data fetch
//  Handles error states for network or data issues
//  Provides retry functionality for failed historical data loads
//  Future: Will display real-time bridge status (if available)
//
//  ## Key Features
//  Error state handling with user-friendly messages for historical data
//  Enhanced loading states for historical API calls
//  Improved route display with historical bridge opening data
//  Retry functionality in error view for historical data
//  Reactive UI updates via @Bindable and @Observable
//

import SwiftData
import SwiftUI

// MARK: - RouteListView

/// A SwiftUI view that displays a list of routes with historical bridge opening data.
///
/// This view provides the main interface for users to browse and select routes.
/// It handles loading states, error conditions, and displays route information
/// including bridge counts, historical openings, and optimization scores.
///
/// ## Overview
///
/// The `RouteListView` is the primary navigation interface that shows all available
/// routes with their associated bridge data. It implements reactive updates using
/// the Observation framework and provides a smooth user experience with proper
/// loading and error states.
///
/// ## Key Features
///
/// - **Reactive Updates**: Automatically updates when route data changes
/// - **Loading States**: Shows progress indicators during data loading
/// - **Error Handling**: Displays user-friendly error messages with retry options
/// - **Route Selection**: Allows users to select and view route details
/// - **Empty States**: Handles cases where no routes are available
///
/// ## Usage
///
/// ```swift
/// RouteListView(appState: appStateModel)
/// ```
///
/// ## Topics
///
/// ### View Components
/// - ``RouteRowView``
///
/// ### State Management
/// - Uses `@Bindable` for reactive updates from `AppStateModel`
/// - Handles loading, error, and empty states
/// - Manages route selection state
struct RouteListView: View {
  @Bindable var appState: AppStateModel

  var body: some View {
    NavigationView {
      VStack(spacing: 0) {
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

        Group {
          if appState.isLoading {
            ProgressView("Loading routes...")
              .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else if appState.routes.isEmpty {
            VStack {
              Image(systemName: "map")
                .font(.system(size: 50))
                .foregroundColor(.gray)
              Text("No routes available")
                .font(.headline)
                .foregroundColor(.gray)
              Text("Routes will appear here once data is loaded")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
          } else {
            List(appState.routes, id: \.routeID) { route in
              RouteRowView(route: route, isSelected: route.routeID == appState.selectedRouteID)
                .onTapGesture {
                  appState.selectRoute(withID: route.routeID)
                }
            }
          }
        }
      }
      .navigationTitle("Seattle Routes")
      .navigationBarTitleDisplayMode(.large)
    }
  }
}

// MARK: - RouteRowView

/// A SwiftUI view that displays a single route row with bridge information.
///
/// This view shows detailed information about a specific route including
/// its score, bridge count, historical openings, and individual bridge details.
///
/// ## Overview
///
/// The `RouteRowView` is a reusable component that displays route information
/// in a compact, readable format. It shows the route's optimization score,
/// number of bridges, total historical openings, and a list of individual bridges.
///
/// ## Key Features
///
/// - **Route Information**: Displays route ID, score, and bridge count
/// - **Historical Data**: Shows total historical openings across all bridges
/// - **Bridge Details**: Lists individual bridges in the route
/// - **Selection State**: Visual feedback for selected routes
/// - **Responsive Layout**: Adapts to different content sizes
///
/// ## Usage
///
/// ```swift
/// RouteRowView(route: routeModel, isSelected: true)
/// ```
///
/// ## Topics
///
/// ### Display Properties
/// - Route ID and optimization score
/// - Bridge count and historical openings
/// - Individual bridge information
/// - Selection state visual feedback
struct RouteRowView: View {
  let route: RouteModel
  let isSelected: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(route.routeID)
          .font(.headline)
          .foregroundColor(isSelected ? .blue : .primary)

        Spacer()

        Text("Score: \(String(format: "%.2f", route.score))")
          .font(.caption)
          .foregroundColor(.secondary)
      }

      Text("\(route.bridges.count) bridges")
        .font(.subheadline)
        .foregroundColor(.secondary)

      Text("Total openings: \(route.totalHistoricalOpenings)")
        .font(.caption)
        .foregroundColor(.secondary)

      if !route.bridges.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Text("Bridges:")
            .font(.caption)
            .foregroundColor(.secondary)

          ForEach(route.bridges, id: \.bridgeName) { bridge in
            HStack {
              Text("• \(bridge.bridgeName)")
                .font(.caption)
              Spacer()
              Text("\(bridge.totalOpenings) openings")
                .font(.caption2)
                .foregroundColor(.secondary)
            }
          }
        }
        .padding(.leading, 8)
      }
    }
    .padding(.vertical, 4)
    .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    .cornerRadius(8)
  }
}

// MARK: - Bridge Data Table Utilities

// 1. List with HStack Rows
struct BridgeTableListView: View {
  let bridges: [BridgeStatusModel]
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Name").bold().frame(minWidth: 80, alignment: .leading)
        Text("ID").bold().frame(minWidth: 40, alignment: .leading)
        Text("Openings").bold().frame(minWidth: 60, alignment: .trailing)
      }
      .padding(.bottom, 2)
      Divider()
      List(bridges, id: \.bridgeName) { bridge in
        HStack {
          Text(bridge.bridgeName)
            .frame(minWidth: 80, alignment: .leading)
          Text(bridge.apiBridgeID?.rawValue ?? "-")
            .frame(minWidth: 40, alignment: .leading)
          Text("\(bridge.totalOpenings)")
            .frame(minWidth: 60, alignment: .trailing)
        }
      }
      .listStyle(.plain)
    }
    .padding()
  }
}

// 2. Grid (LazyVGrid)
struct BridgeTableGridView: View {
  let bridges: [BridgeStatusModel]
  private let columns = [
    GridItem(.flexible(), alignment: .leading),
    GridItem(.fixed(50), alignment: .leading),
    GridItem(.fixed(60), alignment: .trailing),
  ]
  var body: some View {
    VStack(alignment: .leading) {
      LazyVGrid(columns: columns, spacing: 8) {
        Text("Name").bold()
        Text("ID").bold()
        Text("Openings").bold()
        ForEach(bridges, id: \.bridgeName) { bridge in
          Text(bridge.bridgeName)
          Text(bridge.apiBridgeID?.rawValue ?? "-")
          Text("\(bridge.totalOpenings)")
        }
      }
    }
    .padding()
  }
}

// 3. Sectioned List by Route
struct SectionedBridgeListView: View {
  let routes: [RouteModel]
  var body: some View {
    List {
      ForEach(routes, id: \.routeID) { route in
        Section(header: Text(route.routeID)) {
          ForEach(route.bridges, id: \.bridgeName) { bridge in
            HStack {
              Text(bridge.bridgeName)
                .frame(minWidth: 80, alignment: .leading)
              Text(bridge.apiBridgeID?.rawValue ?? "-")
                .frame(minWidth: 40, alignment: .leading)
              Text("\(bridge.totalOpenings)")
                .frame(minWidth: 60, alignment: .trailing)
            }
          }
        }
      }
    }
    .listStyle(.insetGrouped)
  }
}

// ========== Utility Previews ========== //

#Preview("BridgeTableListView (Simple Table List)") {
  let bridges = [
    BridgeStatusModel(bridgeName: "Ballard", apiBridgeID: BridgeID(rawValue: "1"), historicalOpenings: [Date(), Date().addingTimeInterval(-3600)]),
    BridgeStatusModel(bridgeName: "Fremont", apiBridgeID: BridgeID(rawValue: "2"), historicalOpenings: [Date()]),
    BridgeStatusModel(bridgeName: "Spokane St", apiBridgeID: BridgeID(rawValue: "3"), historicalOpenings: [Date(), Date(), Date()]),
  ]
  BridgeTableListView(bridges: bridges)
}

#Preview("BridgeTableGridView (Grid Table)") {
  let bridges = [
    BridgeStatusModel(bridgeName: "Ballard", apiBridgeID: BridgeID(rawValue: "1"), historicalOpenings: [Date(), Date().addingTimeInterval(-3600)]),
    BridgeStatusModel(bridgeName: "Fremont", apiBridgeID: BridgeID(rawValue: "2"), historicalOpenings: [Date()]),
    BridgeStatusModel(bridgeName: "Spokane St", apiBridgeID: BridgeID(rawValue: "3"), historicalOpenings: [Date(), Date(), Date()]),
  ]
  BridgeTableGridView(bridges: bridges)
}

#Preview("SectionedBridgeListView (Grouped by Route)") {
  let bridges1 = [
    BridgeStatusModel(bridgeName: "Ballard", apiBridgeID: BridgeID(rawValue: "1"), historicalOpenings: [Date(), Date().addingTimeInterval(-3600)]),
    BridgeStatusModel(bridgeName: "Fremont", apiBridgeID: BridgeID(rawValue: "2"), historicalOpenings: [Date()]),
  ]
  let bridges2 = [
    BridgeStatusModel(bridgeName: "Spokane St", apiBridgeID: BridgeID(rawValue: "3"), historicalOpenings: [Date(), Date(), Date()]),
  ]
  let routes = [
    RouteModel(routeID: "North Route", bridges: bridges1, score: 0.91),
    RouteModel(routeID: "South Route", bridges: bridges2, score: 0.88),
  ]
  SectionedBridgeListView(routes: routes)
}
