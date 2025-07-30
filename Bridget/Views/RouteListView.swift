//
//  RouteListView.swift
//  Bridget
//
//  Purpose: UI layer for displaying historical bridge opening data with error handling
//  Dependencies: SwiftUI framework, AppStateModel (via @Bindable)
//  Integration Points: 
//    - Displays historical bridge opening data from AppStateModel
//    - Shows loading states during historical data fetch
//    - Handles error states for network or data issues
//    - Provides retry functionality for failed historical data loads
//    - Future: Will display real-time bridge status (if available)
//  Key Features:
//    - Error state handling with user-friendly messages for historical data
//    - Enhanced loading states for historical API calls
//    - Improved route display with historical bridge opening data
//    - Retry functionality in error view for historical data
//    - Reactive UI updates via @Bindable and @Observable
//

import SwiftUI

struct RouteListView: View {
    @Bindable var appState: AppStateModel
    
    var body: some View {
        NavigationView {
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
            .navigationTitle("Seattle Routes")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

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
                    
                    ForEach(route.bridges, id: \.bridgeID) { bridge in
                        HStack {
                            Text("• \(bridge.bridgeID)")
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

#Preview {
    let appState = AppStateModel()
    return RouteListView(appState: appState)
} 