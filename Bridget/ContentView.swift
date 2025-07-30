//
//  ContentView.swift
//  Bridget
//
//  Created by Peter Jemley on 7/24/25.
//

import SwiftUI

struct ContentView: View {
    @Bindable private var appState: AppStateModel
    
    init() {
        self.appState = AppStateModel()
    }
    
    var body: some View {
        RouteListView(appState: appState)
    }
}

#Preview {
    ContentView()
}
