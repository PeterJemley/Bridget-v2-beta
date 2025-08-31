//
//  RouteListView.swift
//  Bridget
//
//  UI layer for displaying routes and historical bridge data with robust loading/error states.
//  Revised to avoid nested scroll containers and to use NavigationStack consistently.
//

import Observation
import SwiftData
import SwiftUI

struct RouteListView: View {
  @Bindable var appState: AppStateModel

  @State private var routes: [RouteModel] = []
  @State private var isLoadingRoutes = true
  @State private var routeLoadError: Error? = nil
  @State private var selectedRouteID: String? = nil

  // Compact, non-sticky header content to place as the first List row
  private var listHeaderRow: some View {
    VStack(spacing: 8) {
      HStack {
        Image(systemName: "laurel.leading")
          .font(.system(size: 28, weight: .bold))
          .foregroundColor(.green)
        Text("Bridget")
          .font(.largeTitle.bold())
          .foregroundColor(.primary)
        Image(systemName: "laurel.trailing")
          .font(.system(size: 28, weight: .bold))
          .foregroundColor(.green)
      }
      if #available(iOS 17.0, *) {
        let message = try? AttributedString(
          markdown:
          "Ditch the spanxiety and bridge the gap between *you* and on *time*."
        )
        Text(
          message
            ?? "Ditch the spanxiety and bridge the gap between you and on time."
        )
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      } else {
        HStack(spacing: 0) {
          Text("Ditch the spanxiety and bridge the gap between ")
          Text("you").italic()
          Text(" and on ")
          Text("time").italic()
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .lineLimit(2)
      }
      let dataURL = URL(
        string:
        "https://data.seattle.gov/Transportation/SDOT-Drawbridge-Status/gm8h-9449/about_data"
      )!
      Link(destination: dataURL) {
        HStack(spacing: 6) {
          Image(systemName: "info.circle.fill")
            .font(.subheadline)
            .foregroundColor(.blue)
          Text("Data provided by Seattle Open Data API")
            .font(.footnote)
            .foregroundColor(.blue)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .clipShape(Capsule())
      }
    }
    .padding(.vertical, 12)
  }

  var body: some View {
    NavigationStack {
      Group {
        if isLoadingRoutes {
          // Centered loading state, no outer ScrollView
          VStack {
            ProgressView()
              .progressViewStyle(.circular)
              .padding(.bottom, 8)
            Text("Loading routes…")
              .font(.footnote)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity,
                 maxHeight: .infinity,
                 alignment: .center)
          .padding()
        } else if let error = routeLoadError {
          // Centered error state, no outer ScrollView
          VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
              .font(.system(size: 40))
              .foregroundColor(.red)
            Text("Failed to load routes.")
              .font(.headline)
            Text(error.localizedDescription)
              .font(.caption)
              .foregroundColor(.secondary)
              .multilineTextAlignment(.center)
              .padding(.horizontal)
            Button(action: {
              Task { await loadRoutes() }
            }) {
              Text("Retry")
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
          }
          .frame(maxWidth: .infinity,
                 maxHeight: .infinity,
                 alignment: .center)
          .padding()
        } else if routes.isEmpty {
          // Centered empty state, no outer ScrollView
          VStack(spacing: 12) {
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
          .frame(maxWidth: .infinity,
                 maxHeight: .infinity,
                 alignment: .center)
          .padding()
        } else {
          // Only one scroll container: the List
          List {
            // Non-sticky header as first row
            listHeaderRow
              .listRowInsets(
                EdgeInsets(top: 8,
                           leading: 16,
                           bottom: 8,
                           trailing: 16)
              )
              .listRowBackground(Color.clear)

            // Optional validation failures banner
            if !appState.validationFailures.isEmpty {
              VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                  Image(
                    systemName:
                    "exclamationmark.triangle.fill"
                  )
                  .foregroundColor(.yellow)
                  Text(
                    "Some records were skipped due to data validation errors."
                  )
                  .font(.footnote)
                  .foregroundColor(.secondary)
                }
                .padding(.bottom, 2)
                ForEach(appState.validationFailures.prefix(5),
                        id: \.reason.description)
                { failure in
                  Text("• \(failure.reason.description)")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .lineLimit(1)
                    .truncationMode(.tail)
                }
                if appState.validationFailures.count > 5 {
                  Text(
                    "...and \(appState.validationFailures.count - 5) more"
                  )
                  .font(.caption2)
                  .foregroundColor(.secondary)
                }
              }
              .padding(10)
              .background(Color.yellow.opacity(0.1))
              .cornerRadius(10)
              .listRowInsets(
                EdgeInsets(top: 0,
                           leading: 16,
                           bottom: 0,
                           trailing: 16)
              )
            }

            // Routes
            ForEach(routes, id: \.routeID) { route in
              RouteRowView(route: route,
                           isSelected: route.routeID == selectedRouteID)
                .contentShape(Rectangle())
                .onTapGesture {
                  selectedRouteID = route.routeID
                }
            }
          }
          .listStyle(.insetGrouped)
        }
      }
      .navigationTitle("Routes")
      .navigationBarTitleDisplayMode(.large)
      .onAppear {
        guard isLoadingRoutes else { return }
        Task { await loadRoutes() }
      }
    }
  }

  private func loadRoutes() async {
    isLoadingRoutes = true
    routeLoadError = nil
    do {
      let (bridges, _) = try await BridgeDataService.shared
        .loadHistoricalData()
      let genRoutes = BridgeDataService.shared.generateRoutes(
        from: bridges
      )
      await MainActor.run {
        self.routes = genRoutes
        self.isLoadingRoutes = false
      }
    } catch {
      await MainActor.run {
        self.isLoadingRoutes = false
        self.routeLoadError = error
      }
    }
  }
}

// MARK: - RouteRowView

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

// MARK: - Bridge Data Table Utilities (unchanged)

struct BridgeTableListView: View {
  let bridges: [BridgeStatusModel]
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("Name").bold().frame(minWidth: 80, alignment: .leading)
        Text("ID").bold().frame(minWidth: 40, alignment: .leading)
        Text("Openings").bold().frame(minWidth: 60,
                                      alignment: .trailing)
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

#Preview("BridgeTableListView (Simple Table List)") {
  let bridges = [
    BridgeStatusModel(bridgeName: "Ballard",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "1"),
                      historicalOpenings: [Date(), Date().addingTimeInterval(-3600)]),
    BridgeStatusModel(bridgeName: "Fremont",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "2"),
                      historicalOpenings: [Date()]),
    BridgeStatusModel(bridgeName: "Spokane St",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "3"),
                      historicalOpenings: [Date(), Date(), Date()]),
  ]
  BridgeTableListView(bridges: bridges)
}

#Preview("BridgeTableGridView (Grid Table)") {
  let bridges = [
    BridgeStatusModel(bridgeName: "Ballard",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "1"),
                      historicalOpenings: [Date(), Date().addingTimeInterval(-3600)]),
    BridgeStatusModel(bridgeName: "Fremont",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "2"),
                      historicalOpenings: [Date()]),
    BridgeStatusModel(bridgeName: "Spokane St",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "3"),
                      historicalOpenings: [Date(), Date(), Date()]),
  ]
  BridgeTableGridView(bridges: bridges)
}

#Preview("SectionedBridgeListView (Grouped by Route)") {
  let bridges1 = [
    BridgeStatusModel(bridgeName: "Ballard",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "1"),
                      historicalOpenings: [Date(), Date().addingTimeInterval(-3600)]),
    BridgeStatusModel(bridgeName: "Fremont",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "2"),
                      historicalOpenings: [Date()]),
  ]
  let bridges2 = [
    BridgeStatusModel(bridgeName: "Spokane St",
                      apiBridgeID: SeattleDrawbridges.BridgeID(rawValue: "3"),
                      historicalOpenings: [Date(), Date(), Date()]),
  ]
  let routes = [
    RouteModel(routeID: "North Route", bridges: bridges1, score: 0.91),
    RouteModel(routeID: "South Route", bridges: bridges2, score: 0.88),
  ]
  SectionedBridgeListView(routes: routes)
}
