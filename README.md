# Seattle Route Optimization App - Engineering Plan

## Core Engineering Requirements Synopsis

- [ ] Use Apple's Observation framework exclusively (`@Observable`, `withObservationTracking`)
- [ ] Fully leverage Apple macros (`@Observable`, `@ObservationIgnored`, etc.)
- [ ] Integrate non-real-time bridge opening data (Seattle Open Data API)
- [ ] Integrate real-time slowdown data (from Apple Maps, processed via Core ML + ANE)
- [ ] Perform inference on-device using Core ML + Neural Engine
- [ ] Ensure strict modularity, favoring decomposition over co-located logic
- [ ] All updates to data must reactively update the UI

## Observation-First SwiftData App Architecture: Engineering Standards & Checklist

### Observation Framework Compliance
- [ ] All observable types use @Observable macro (never manual Observable conformance)
- [ ] All views use @Bindable for state passed from models
- [ ] Any derived view-specific state is wrapped in @ObservationIgnored to prevent redundant observation
- [ ] withObservationTracking is used in performance-sensitive areas with custom onChange closures
- [ ] No use of @StateObject, @ObservedObject, or Combine-based publishers
- [ ] All app state is stored in @Observable types, not @State or @EnvironmentObject

### Apple Macro Usage
- [ ] All models use @Observable macro instead of protocol conformance
- [ ] Use @ObservationIgnored for non-reactive properties (e.g. timestamps, caches)
- [ ] No Apple macro is used outside of its intended context (e.g. @ObservationTracked only used by system)
- [ ] No redundant manual observation registration (e.g., ObservationRegistrar) unless low-level tuning is necessary

### Data Integration (Non-Real-Time)
- [x] Non-live data (Seattle Open Data API) is fetched asynchronously and decoded into @Observable models
- [x] Bridge openings are pre-processed (e.g., grouped by time, bridge ID, or frequency buckets)
- [x] Data ingestion logic is encapsulated in a dedicated, testable service (e.g., BridgeDataService)
- [x] Models only expose data needed by the view — heavy computation or preprocessing is offloaded
- [x] HTTP requests and parsing do not occur in any view or model directly

### Real-Time Data Integration + Core ML
- [ ] Real-time traffic slowdowns are collected from Apple Maps API or similar endpoint
- [ ] Data is converted to model-compatible input (e.g., MLMultiArray)
- [ ] Inference runs on-device using MLModelConfiguration(computeUnits: .all) (for ANE support)
- [ ] Core ML output is immediately reflected in @Observable models (e.g., realTimeDelay)
- [ ] No model inference occurs in the view layer or @Observable model initializers

### Inference + ANE Optimization
- [ ] ML model is quantized (e.g., 16-bit or 8-bit if possible)
- [ ] Model input preprocessing and output postprocessing are offloaded to TrafficInferenceService
- [ ] Large batch inference uses vectorized input instead of sequential requests
- [ ] Matrix and tensor operations use Accelerate, BNNS, or custom utilities where appropriate
- [ ] All inference computations are tested offline and evaluated for latency on-device

### Modular Structure
- [x] All functionality is encapsulated in dedicated modules (views, services, models, utils, etc.)
- [x] No service or model file is longer than ~200 LOC without clear justification
- [ ] Views do not include API requests, ML logic, or scoring logic
- [ ] Scoring logic (e.g., route ranking) is in a dedicated service (e.g., RouteScoringService)
- [x] All logic can be tested in isolation from the UI layer
- [x] Global state (e.g., AppStateModel) is the only shared object passed down hierarchies
- [x] Shared dependencies (e.g., services) are injected, not hardcoded

### UI Reactivity and Responsiveness
- [ ] Every data change in a model is reflected in the view via @Bindable
- [ ] Long-running tasks (e.g., API calls, inference) update isLoading states in a model
- [ ] Views adapt instantly when @Observable state updates
- [ ] UI never blocks during data updates (async tasks properly detached)
- [ ] Complex views (e.g., map) isolate sub-observation to avoid full redraws
- [ ] Skeleton views, loading indicators, and placeholders are driven by observable booleans

### Code Hygiene and Evaluation Strategy
- [ ] Each Swift file starts with a file-level comment identifying its module purpose and integration points
- [ ] Every service has a minimal public API and is internal by default
- [ ] All async tasks use Task {} or async let — no background threads directly spawned
- [ ] View structs are < 150 LOC and split into subviews where possible
- [ ] Every model and service is covered by a minimal unit test scaffold
- [ ] All bridge and route updates are logged (in dev builds) with timestamps and route IDs

### Summary View (for integration into repo or project README)

#### Engineering Lint Summary

- [x] Observation Framework Used Exclusively
- [x] Apple Macros Fully Leveraged
- [x] Non-Real-Time Data Integrated via Decoupled Service
- [ ] Real-Time Inference Performed On-Device via ANE
- [ ] ML Inference and Matrix Computation Modularized
- [x] Strict Modularity Maintained Across Codebase
- [x] All UI Fully Reactive to Observed Data Changes

## Modular Architecture Overview

```
App
├── Models/
│   ├── @Observable BridgeStatusModel.swift
│   ├── @Observable RouteModel.swift
│   └── @Observable AppStateModel.swift
│
├── Services/
│   ├── BridgeDataService.swift (143 LOC - orchestration layer)
│   ├── NetworkClient.swift (121 LOC - network operations)
│   ├── CacheService.swift (143 LOC - disk I/O and caching)
│   ├── BridgeDataProcessor.swift (201 LOC - data processing)
│   ├── SampleDataProvider.swift (85 LOC - mock data)
│   ├── TrafficInferenceService.swift (planned - Core ML + ANE)
│   └── RouteScoringService.swift (planned - matrix-based scoring)
│
├── ML/
│   └── TrafficImpactModel.mlmodelc (planned - compiled Core ML)
│
├── Views/
│   ├── RouteListView.swift
│   ├── RouteDetailView.swift (planned)
│   └── LoadingView.swift (planned)
│
├── Utilities/
│   ├── MatrixUtils.swift (planned - Accelerate framework utilities)
│   ├── LoggingUtils.swift (planned - with #file, #function macros)
│   └── AssetUtils.swift (planned - with #fileLiteral, #imageLiteral)
│
└── App.swift (entry point with @main and top-level observation bindings)
```

## Observation Framework Usage

### 1. Define Reactive State Models

```swift
@Observable
class BridgeStatusModel {
    var bridgeID: String
    var historicalOpenings: [Date]
    var realTimeDelay: TimeInterval? // computed from ML

    init(bridgeID: String, historicalOpenings: [Date]) {
        self.bridgeID = bridgeID
        self.historicalOpenings = historicalOpenings
    }
}

@Observable
class RouteModel {
    var routeID: String
    var bridgeStatuses: [BridgeStatusModel]
    var score: Double = 0.0 // computed
}

@Observable
class AppStateModel {
    var routes: [RouteModel] = []
    var isLoading: Bool = false
    var selectedRouteID: String?
}
```

Use `@ObservationIgnored` for any internal cache or timestamp fields that shouldn't trigger view updates.

## Services

### BridgeDataService.swift (Refactored - 143 LOC)
- [x] Orchestrates specialized services for data loading
- [x] Implements cache-first strategy with graceful degradation
- [x] Provides fallback to sample data for testing
- [x] Maintains clean separation of concerns

### NetworkClient.swift (121 LOC)
- [x] Handles all URLSession calls, retry logic, header management
- [x] Implements exponential backoff retry strategy
- [x] Validates HTTP responses and payload sizes
- [x] Provides robust network error handling

### CacheService.swift (143 LOC)
- [x] Manages disk I/O operations and cache validation
- [x] Handles JSON encoding/decoding for persistence
- [x] Provides cache expiration and size management utilities
- [x] Implements cache directory management

### BridgeDataProcessor.swift (201 LOC)
- [x] Decodes JSON data and validates business rules
- [x] Groups records by bridge ID and maps to BridgeStatusModel
- [x] Filters invalid records based on business logic
- [x] Handles data transformation and validation

### SampleDataProvider.swift (85 LOC)
- [x] Keeps mock data fallback isolated from production code
- [x] Provides consistent test data for development
- [x] Generates sample routes for testing scenarios

```swift
class BridgeDataService {
    private let networkClient = NetworkClient.shared
    private let cacheService = CacheService.shared
    private let dataProcessor = BridgeDataProcessor.shared
    private let sampleProvider = SampleDataProvider.shared
    
    func loadHistoricalData() async throws -> [BridgeStatusModel] {
        // Orchestrates network, cache, and data processing operations
    }
}
```

### TrafficInferenceService.swift (Planned)
- [ ] Runs real-time Apple Maps traffic data through Core ML model
- [ ] Uses MLModelConfiguration with .computeUnits = .all to enable ANE

```swift
actor TrafficInferenceService {
    private let model = try? TrafficImpactModel(configuration: MLModelConfiguration().apply {
        $0.computeUnits = .all
    })

    @Sendable
    func inferSlowdowns(for locations: [CLLocation]) async throws -> [String: TimeInterval] {
        // Convert inputs to MLMultiArray, run model prediction
        #assert(locations.count > 0, "Must provide at least one location for inference")
    }
}
```

### RouteScoringService.swift (Planned)
- [ ] Combines historical opening frequency and ML-inferred delays into a route score
- [ ] Matrix-weighted computation (Accelerate or custom MatrixUtils.swift)

```swift
actor RouteScoringService {
    func score(route: RouteModel) -> Double {
        // e.g., weighted sum of predicted delay + frequency
    }
}
```

## ML Design & ANE Strategy

- [ ] The Core ML model should take features like:
  - [ ] Nearby traffic density
  - [ ] Bridge open probabilities
  - [ ] Time of day, day of week
- [ ] You can use Create ML, Turi Create, or PyTorch CoreML conversion for model training
- [ ] Quantize where possible to optimize for ANE

## withObservationTracking (Selective Reactivity)

For performance hotspots:

```swift
withObservationTracking {
    renderRouteList(model.routes) // only track .routes, not .isLoading
} onChange: {
    print("Routes changed")
}
```

Use this in long-lived views (e.g. route map updates) to avoid over-refreshing.

## UI Binding Example (SwiftUI)

```swift
struct RouteListView: View {
    @Bindable var state: AppStateModel

    var body: some View {
        List(state.routes, id: \.routeID) { route in
            Text("Route \(route.routeID): Score \(route.score)")
        }
    }
}

#Preview("Route List") {
    RouteListView(state: AppStateModel())
}
```

Avoid `@StateObject`, `@ObservedObject`, or Combine. Instead, use `@Bindable` (Observation-compliant) and bind to `@Observable` models.

## Macro Compliance

| Macro | Purpose | Usage |
|-------|---------|-------|
| `@Observable` | Core binding macro | Applied to all state/data models |
| `@ObservationIgnored` | Opt-out of observation | Applied to internal-only fields |
| `withObservationTracking` | Fine-grained change tracking | Applied around view rendering or side-effects |
| `@ViewBuilder` | UI composition | Custom view initializers and helper methods |
| `@MainActor` | Thread safety | UI-impacting service and view-model methods |
| `@Sendable` | Concurrency safety | Task-spawned closures in services |
| `#Preview` | Development | Live canvas previews for rapid UI iteration |
| `#warning` / `#error` | Compile-time diagnostics | TODOs and unsupported configuration guards |
| `#assert` | Compile-time assertions | Swift 5.9+ compile-time validation |
| `#file` / `#function` | Debugging | Logging helpers for precise call-site data |

## Project Startup Strategy

### Phase 1: Data Ingestion & State Modeling ✅ COMPLETE
- [x] Implement BridgeStatusModel, RouteModel, AppStateModel
- [x] Load and bind historical data from Seattle JSON
- [x] Refactored BridgeDataService for modularity (under 200 LOC guideline)
- [x] Created specialized services: NetworkClient, CacheService, BridgeDataProcessor, SampleDataProvider
- [x] Test coverage includes API integration, network error handling, caching, and JSON processing (exceeds Phase 1 scope)
- [x] Added comprehensive DocC documentation to AppStateModel with proper /// comments
- [x] Implemented SwiftLint and SwiftFormat with battle-tested configurations
- [x] Set up git pre-commit hooks for automatic code formatting and linting
- [x] Created development tools package (BridgetTools) with pinned versions
- [x] Added code quality documentation and troubleshooting guides

### Phase 2: Core ML Model Integration
- [ ] Define real-time inference pipeline using Core ML + ANE
- [ ] Integrate with BridgeStatusModel.realTimeDelay

### Phase 3: Scoring & Matrix Computation
- [ ] Build matrix-based RouteScoringService
- [ ] Use Accelerate or custom math functions

### Phase 4: Observation Integration in Views
- [ ] Bind views to models via Observation macros
- [ ] Use @Bindable and withObservationTracking as needed

## Implementation Notes

- All data models must use `@Observable` for reactive UI updates
- Use `@ObservationIgnored` for internal state that shouldn't trigger updates
- Core ML model should be optimized for Apple Neural Engine (ANE)
- Services should be implemented as actors for thread safety
- Matrix computations should leverage Accelerate framework where possible
- UI should be built with SwiftUI using `@Bindable` for Observation compliance

## Additional Apple Macros Integration

### Resource & Debugging Literals
- [ ] `#fileLiteral(resourceName:)` - Embed sample JSON data in Utilities/AssetUtils.swift
- [ ] `#imageLiteral(resourceName:)` - Placeholder images for route visualization
- [ ] `#colorLiteral(red:green:blue:alpha:)` - Color swatches for UI theming
- [ ] `#file`, `#function` - Logging helpers in Utilities/LoggingUtils.swift for precise call-site data

### Diagnostics & Conditional Compilation
- [ ] `#warning("TODO: Implement Core ML model training")` - Mark incomplete features
- [ ] `#error("ANE not available on this device")` - Guard unsupported configurations
- [ ] `#assert(condition, "message")` - Compile-time validation in Core ML inference
- [ ] `#if DEBUG` - Development-only logging and debugging features
- [ ] `#if os(iOS)` - Platform-specific optimizations

### Declarative & UI Macros
- [ ] `@ViewBuilder` - Custom view initializers for modular UI composition
- [ ] `#Preview` - Live canvas previews for all views (RouteListView, RouteDetailView, LoadingView)

### Concurrency & Actor Isolation
- [ ] `@MainActor` - UI-impacting service methods (BridgeDataService, RouteScoringService)
- [ ] `@Sendable` - Task-spawned closures in TrafficInferenceService and async operations

### Custom Macros for Core ML
- [ ] Consider custom macro for repetitive MLModelConfiguration boilerplate
- [ ] Custom macro for [CLLocation] → MLMultiArray conversion patterns
- [ ] Macro for ANE-optimized model loading with .computeUnits = .all

## Code Quality & Development Tools ✅ IMPLEMENTED

### Development Tools Setup
- [x] **SwiftLint and SwiftFormat** installed via Swift Package Manager
- [x] **Git pre-commit hooks** configured for automatic formatting and linting
- [x] **Battle-tested configurations** for both tools with proper exclusions
- [x] **Development tools package** (BridgetTools) with pinned versions
- [x] **Comprehensive documentation** and troubleshooting guides

### Documentation Standards
- [x] **DocC documentation** added to AppStateModel with proper /// comments
- [x] **Git hooks documentation** (GIT_HOOKS_README.md)
- [x] **Code quality troubleshooting guides**

### Tool Versions (Pinned)
- SwiftLint: 0.50.0+ (via Package.swift)
- SwiftFormat: 0.51.0+ (via Package.swift)

### Quick Fixes
```bash
# Auto-fix SwiftLint violations
swift run swiftlint autocorrect --config .swiftlint.yml

# Check remaining issues
swift run swiftlint lint --config .swiftlint.yml

# Format code with SwiftFormat
swift run swiftformat . --config .swiftformat
```

### Pre-commit Hook Behavior
The project uses Git hooks that automatically:
1. Format code with SwiftFormat
2. Auto-fix SwiftLint violations
3. Block commits on remaining errors
4. Re-stage modified files
