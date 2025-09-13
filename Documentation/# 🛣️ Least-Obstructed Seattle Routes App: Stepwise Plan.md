# 🛣️ Least-Obstructed Seattle Routes App: Stepwise Plan

Below is a pattern you can follow to cleanly separate ML (ANE-accelerated inference) from "traditional" logic (CPU/Accelerate), while keeping everything reactive via the Observation framework.

## Architecture Overview

```mermaid
flowchart TD
  subgraph Ingestion
    A1[BridgeEventFetcher] --> M1[BridgeEvent @Model]
    A2[TrafficDataProvider] --> M2[TrafficSnapshot @Model]
  end

  subgraph Inference (ANE/Core ML)
    M1 --> P1[BridgeObstructionPredictor]
    P1 --> M3[EventObstructionScore @AsyncComputed]
  end

  subgraph Logic (CPU / Accelerate)
    M2 --> L1[GraphWeightUpdater]
    L1 --> L2[PathfindingEngine]
  end

  subgraph UI (Observation + SwiftUI)
    M3 --> V1[BridgeListView @Query]
    L2 --> V2[RouteMapView @Observable]
  end
```

---

## 1. Xcode Project Setup
- [ ] Create a new SwiftUI App (File → New → Project → “App”, Interface: SwiftUI, “Use Core Data” unchecked)
- [ ] Add Observation & SwiftData frameworks to the project
- [ ] Enable and configure ModelContainer for SwiftData entities
  - [ ] Example:
    ```swift
    @main
    struct BridgeMonitorApp: App {
      @State private var container = ModelContainer(for: [
        BridgeEvent.self,
        TrafficSnapshot.self
      ])
      var body: some Scene {
        WindowGroup {
          BridgeListView()
            .modelContainer(container)
        }
      }
    }
    ```

---

## 2. Define Persistent, Observable Models
- [ ] Define `BridgeEvent` entity with `@Model @Observable`
- [ ] Define `TrafficSnapshot` entity with `@Model @Observable`
- [ ] Add computed and async-computed properties (e.g., `obstructionScore`) to models
  - [ ] Example:
    ```swift
    import Observation
    import SwiftData

    @Model @Observable
    final class BridgeEvent {
      @Attribute(.unique) var id: String
      var timestamp: Date
      var historicalFlow: Double

      @AsyncComputed(kind: .concurrency)
      var obstructionScore: Double {
        await BridgeObstructionPredictor.shared.predictAsync(flow: historicalFlow)
      }
    }

    @Model @Observable
    final class TrafficSnapshot {
      @Attribute(.unique) var id: UUID = .init()
      var timestamp: Date
      var realtimeFlow: Double
    }
    ```

---

## 3. Core ML Predictor Singleton & ANE Guidance
- [ ] Add and compile the Core ML model (`ObstructionPredictor.mlmodel`)
- [ ] Implement `BridgeObstructionPredictor` singleton with ANE acceleration
- [ ] Implement async prediction method for use in `@AsyncComputed` properties
  - [ ] Example:
    ```swift
    import CoreML

    class BridgeObstructionPredictor {
      static let shared = BridgeObstructionPredictor()
      private let model: ObstructionPredictor

      private init() {
        var cfg = MLModelConfiguration()
        cfg.computeUnits = .all   // ANE + GPU + CPU fallback
        model = try! ObstructionPredictor(configuration: cfg)
      }

      func predict(flow: Double) -> Double {
        let input = ObstructionPredictorInput(flow: flow)
        return (try? model.prediction(input: input).obstructionProbability) ?? 0
      }

      func predictAsync(flow: Double) async -> Double {
        await withCheckedContinuation { cont in
          DispatchQueue.global(qos: .userInitiated).async {
            let result = self.predict(flow: flow)
            cont.resume(returning: result)
          }
        }
      }
    }
    ```
- [ ] Document ANE/CPU split:
  - ANE: Matrix multiplies, tensor ops, neural net layers (MLP, LSTM, small transformer), batch scoring
  - CPU/Accelerate: Graph algorithms (Dijkstra/A*), custom linear algebra, large matrix math
- [ ] Create Hybrid Strategy Table for clarity:
  | Task | Compute On | Framework |
  |------|------------|-----------|
  | Neural inference (obstruction scoring) | ANE | Core ML |
  | Graph algorithms (Dijkstra/A*) | CPU | Custom |
  | Large matrix math | CPU/Accelerate | Accelerate |
  | Real-time traffic processing | CPU | MapKit |
  | Historical data processing | CPU | SwiftData |

---

## 4. BridgeEventFetcher (Twice-Daily Seattle Feed)
- [ ] Define `APIEvent` struct for decoding
- [ ] Implement `BridgeEventFetcher` to fetch and decode Seattle bridge data
- [ ] Write fetched events into SwiftData context
  - [ ] Example:
    ```swift
    struct APIEvent: Decodable {
      let id: String
      let date: String   // ISO 8601
      let flow: Double
    }

    class BridgeEventFetcher {
      private let url = URL(string:
        "https://data.seattle.gov/resource/gm8h-9449.json"
      )!

      /// Call twice daily—batch feed lags real-time.
      func fetch(into context: ModelContext) async throws {
        let (data, _) = try await URLSession.shared.data(from: url)
        let events = try JSONDecoder().decode([APIEvent].self, from: data)
        for api in events {
          let evt = BridgeEvent(
            id: api.id,
            timestamp: ISO8601DateFormatter().date(from: api.date)!,
            historicalFlow: api.flow
          )
          context.insert(evt)
        }
        try context.save()
      }
    }
    ```

---

## 5. Scheduling Refreshes
- [ ] Implement twice-daily refresh (6 AM & 6 PM local time)
- [ ] Use NotificationCenter to trigger data refreshes
  - [ ] Example:
    ```swift
    extension Task where Success==Void, Failure==Error {
      static func scheduleTwiceDaily() async {
        let cal = Calendar.current
        while true {
          let now = Date()
          let hour = cal.component(.hour, from: now)
          let nextHour = hour < 6 ? 6 : (hour < 18 ? 18 : 6)
          let next = cal.nextDate(after: now,
                                  matching: DateComponents(hour: nextHour),
                                  matchingPolicy: .nextTime)!
          try? await Task.sleep(until: next, clock: .continuous)
          NotificationCenter.default.post(name: .bridgeDataRefresh, object: nil)
        }
      }
    }
    ```

---

## 6. TrafficDataProvider (MapKit)
- [ ] Implement `TrafficDataProvider` using MapKit and CoreLocation
- [ ] Write real-time traffic snapshots into SwiftData context
  - [ ] Example:
    ```swift
    import MapKit

    class TrafficDataProvider: NSObject, CLLocationManagerDelegate {
      private let locationManager = CLLocationManager()

      func start(into context: ModelContext) {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
      }

      func locationManager(_ mgr: CLLocationManager,
                           didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last else { return }
        let req = MKDirections.Request()
        req.source = MKMapItem(placemark: MKPlacemark(coordinate: loc.coordinate))
        // set destination across target bridge…
        MKDirections(request: req).calculate { resp, _ in
          if let route = resp?.routes.first {
            let snap = TrafficSnapshot(
              timestamp: Date(),
              realtimeFlow: route.expectedTravelTime
            )
            context.insert(snap)
            try? context.save()
          }
        }
      }
    }
    ```
- [ ] Note: Real-time snapshots update on each location change.

---

## 7. RoutePlanner / Pathfinding Engine
- [ ] Implement `RoutePlanner` class with graph algorithms
- [ ] Create `GraphWeightUpdater` to update adjacency matrix from traffic data
- [ ] Implement `PathfindingEngine` using Dijkstra/A* algorithm
  - [ ] Example:
    ```swift
    @Observable class RoutePlanner {
      private var adjacency: AdjacencyMatrix = // ...
      func updateWeights(from snap: TrafficSnapshot, and events: [BridgeEvent]) { 
        // Update graph weights based on traffic and historical data
      }
      func bestRoute(from: Node, to: Node) -> [Node] { 
        // Return optimal route using Dijkstra/A*
      }
    }
    ```

## 8. SwiftUI Views with @Query & Refresh
- [ ] Build `BridgeListView` using `@Query` for live-updating event lists
- [ ] Build `RouteMapView` to visualize candidate routes and obstruction risks
- [ ] Ensure all views are reactive via Observation/SwiftData (no Combine)
  - [ ] Example:
    ```swift
    struct BridgeListView: View {
      @Environment(\.modelContext) var context
      @Query(sort: \.timestamp, order: .forward) var events: [BridgeEvent]
      @Observable var planner = RoutePlanner()

      var body: some View {
        List(events) { evt in
          HStack {
            Text(evt.id)
            Spacer()
            Text(evt.obstructionScore,
                 format: .number.precision(.fractionLength(2)))
          }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: .bridgeDataRefresh)
        ) { _ in
          Task { try? await BridgeEventFetcher().fetch(into: context) }
        }
        .onChange(of: events) { all in
          Task { @MainActor in
            if let snap = try? await fetchLatestTraffic(context) {
              planner.updateWeights(from: snap, and: all)
              _ = planner.bestRoute(from: .start, to: .end)
            }
          }
        }
        .task {
          Task.scheduleTwiceDaily()
          try? await BridgeEventFetcher().fetch(into: context)
          TrafficDataProvider().start(into: context)
        }
      }
    }
    ```

---

## 9. Concurrency & Error Handling
- [ ] Offload heavy ML via Task.detached or async properties
- [ ] Surface errors in an `@Observable` AppState.errorMessage

---

## 10. Testing & CI Integration
- [ ] Write unit tests for JSON decoding, ML inference, and computed properties
- [ ] Write UI tests for list and map content after data loads/refreshes
- [ ] Set up CI hooks for linting and test enforcement

---

## 11. Iterate & Polish
- [ ] Cache ML Results: Persist last obstructionScore if inference is costly
- [ ] Add accessibility labels and support Dynamic Type
- [ ] Use semantic fonts and color tokens for HIG compliance
- [ ] Optimize for performance and battery life

---

With this structure, your app runs all neural-net inference on the ANE, keeps graph algorithms on the CPU (or Accelerate), and wires everything reactively via the Observation framework. 
