# Seattle Route Optimization Plan

## Current State

**Phase 1: Historical Data Integration** ✅ **COMPLETED**
- Successfully integrated with Seattle Open Data API: `https://data.seattle.gov/resource/gm8h-9449.json`
- **Historical bridge opening data only** - no real-time bridge status available
- Implemented proper JSON decoding for historical bridge opening records
- Fixed date parsing to handle actual API format (`yyyy-MM-dd'T'HH:mm:ss.SSS`)
- All tests passing with historical data
- Cache infrastructure prepared for Phase 2

**Phase 1.5: Data Validation & Error Handling** ✅ **COMPLETED**
- Enhanced API response validation with Content-Type and payload size checks
- Implemented comprehensive error classification with detailed diagnostics
- Added business logic validation (bridge ID verification, date range filtering)
- Centralized JSON decoder configuration with key/date strategies
- Added debug logging for validation failures and skipped records
- Comprehensive unit test coverage for all validation branches
- Graceful degradation with detailed error context for production debugging

**Phase 2: Offline Caching** **IN PROGRESS**
- Cache metadata fields implemented with `@ObservationIgnored`
- Cache serialization/deserialization ready
- Retry logic with exponential backoff implemented
- Cache-first strategy implemented

**Phase 3: HTTP Caching Optimization** **BACKLOGGED**
- HTTP conditional GET with ETag/If-None-Match headers
- 304 "Not Modified" response handling
- UserDefaults ETag storage
- Bandwidth optimization for frequent polling scenarios

## Architecture Overview

### Core Components

**Models (Cache Ready)**
- `AppStateModel`: Global state with cache metadata
- `BridgeStatusModel`: Historical bridge data with cache support
- `RouteModel`: Route representation with cache support

**Services (Complete + Cache Infrastructure)**
- `BridgeDataService`: Historical API integration with caching
  - ✅ Historical Seattle API integration
  - ✅ Proper JSON decoding for historical records
  - ✅ Cache serialization/deserialization
  - ✅ Retry logic with exponential backoff
  - ✅ Cache-first strategy
  - 📋 Phase 3: HTTP conditional GET optimization

**Views (Historical Data Display)**
- `RouteListView`: Displays historical bridge opening data
- `ContentView`: Coordinates app state

## Implementation Checklist

### Phase 1: Historical Data Integration ✅

- [x] **Implement historical API integration**
  - [x] Connect to Seattle Open Data API (historical data only)
  - [x] Implement proper JSON decoding for historical records
  - [x] Handle API response format
  - [x] Fix date parsing for actual API format
  - [x] Remove fallback to sample data
  - [x] Test with historical data

- [x] **Error handling for network issues**
  - [x] Implement retry logic
  - [x] Handle network timeouts
  - [x] Provide user-friendly error messages

- [x] **Data validation**
  - [x] Validate API response structure
  - [x] Handle missing or malformed data
  - [x] Test edge cases

### Phase 1.5: Data Validation & Error Handling ✅

- [x] **Enhanced API response validation**
  - [x] Content-Type header validation with debug logging
  - [x] Payload size validation (5MB limit for safety)
  - [x] HTTP status code validation
  - [x] Empty response handling

- [x] **Comprehensive error classification**
  - [x] Enhanced BridgeDataError enum with associated context
  - [x] LocalizedError conformance for user-friendly messages
  - [x] Detailed error descriptions for debugging
  - [x] Raw data preservation for error analysis

- [x] **Business logic validation**
  - [x] Known bridge ID validation with graceful filtering
  - [x] Date range validation (10 years back, 1 year forward)
  - [x] Required field validation with detailed logging
  - [x] Skipped record counting and reporting

- [x] **Centralized JSON processing**
  - [x] Key decoding strategy for flexible JSON handling
  - [x] Date decoding strategy for automatic parsing
  - [x] Proper error wrapping with debug context
  - [x] Comprehensive unit test coverage

### Phase 2: Offline Caching + Micro-UI

- [x] **Implement data caching for offline support**
  - [x] Cache metadata fields with `@ObservationIgnored`
  - [x] Cache serialization/deserialization
  - [x] Cache validation and expiration
  - [x] Cache-first strategy

- [ ] **Complete offline caching infrastructure**
  - [ ] Implement offline mode detection
  - [ ] Implement background refresh
  - [ ] Schedule twice-daily fetches
  - [ ] Add basic cache management UI (settings/preferences)

- [ ] **Micro-UI improvements for immediate UX**
  - [ ] Add ProgressView during data loading
  - [ ] Add skeleton placeholders for route list items
  - [ ] Surface errors with standard SwiftUI .alert and retry button
  - [ ] Basic loading states for cache operations

**Phase 2 Strategy**: Complete core offline caching logic while adding micro-UI improvements for immediate user feedback. Focus on foundation-first approach with small, self-contained UX tasks that provide immediate payoff without waiting for major visual polish.

**Key gaps to address next:**
- **Performance hooks**: add withObservationTracking for any hot loops (e.g. route scoring).
- **Real-time + Core ML**: build out a TrafficInferenceService, quantize models, integrate Apple Maps slowdowns.
- **Scoring isolation**: move ranking logic into its own RouteScoringService.
- **Enhanced UI states**: add skeleton rows or richer loading placeholders.
- **Logging**: instrument debug-only logs for bridge/route updates.

## Ongoing Quality & Future-Proofing Strategy

### 1. Ongoing Code Quality & Stability
- **Automated CI Checks**
  - Enforce linting (SwiftLint), formatting (SwiftFormat), and compile-time warnings
  - Run unit tests on every pull request, plus watch for coverage drops
- **Expand Test Coverage**
  - Add integration tests that spin up real or mocked BridgeDataService to hit HTTP-cache and error paths
  - Introduce UI tests (XCTest + XCTestUI) to verify loading indicators, error alerts, and skeleton views

### 2. Observability & Monitoring
- **Runtime Metrics**
  - Instrument service layer with lightweight timing (signpost/logging) to measure "time-to-load" in staging/production
  - Surface metrics back into app or analytics dashboard for trend-watching
- **Error Reporting**
  - Hook BridgeDataError cases into Sentry or crash-reporting tool to see which error branches fire in production

### 3. Performance & Resource Management
- **Profile on Device**
  - Use Instruments to watch for memory spikes during JSON decoding or Core ML inference
  - If maps/charts come later, verify that sub-observation avoids full-view redraws
- **Refine Observation Tracking**
  - Introduce withObservationTracking around hot loops (route scoring, data grouping) if slowdown or redundant updates are spotted

### 4. Documentation & Onboarding
- **Living README**
  - Update project README with "How to run the disk-cache scheduler," "How to simulate API failures," and "How to add new bridges to your model"
- **Architectural Diagrams**
  - Consider simple sequence or component diagram (Mermaid or PlantUML) showing data flow from network → cache → model → view

### 5. Future-Proofing for Phase 3 and Beyond
- **Plugin Points**
  - Keep BridgeDataService API surface stable even as Core ML or real-time feeds are swapped in
  - Design RouteScoringService with clear protocol so A/B testing different algorithms doesn't require UI changes
- **Versioning & Migration**
  - If Open Data schema changes or ML model upgrades, plan for lightweight migration logic (e.g. "if new field X is present, use it; else fallback")

### Phase 3: HTTP Caching Optimization

- [ ] **Implement HTTP conditional GET**
  - [ ] Add ETag/If-None-Match header support
  - [ ] Handle 304 "Not Modified" responses
  - [ ] Store ETags in UserDefaults
  - [ ] Optimize for bandwidth efficiency

- [ ] **Background fetch optimization**
  - [ ] Implement BGAppRefreshTaskRequest
  - [ ] Schedule morning and evening fetches
  - [ ] Minimize unnecessary network calls

### Code Quality

- [x] **Use @Observable for reactive state management**
- [x] **Use @ObservationIgnored for non-reactive properties (e.g. timestamps, caches)**
- [x] **Implement proper error handling**
- [x] **Add comprehensive unit tests**
- [x] **Add file-level documentation**

## Technical Details

### API Integration

**Endpoint**: `https://data.seattle.gov/resource/gm8h-9449.json`
**Data Type**: **Historical bridge opening records only**
**Response Format**: Array of historical bridge opening records
**Date Format**: `yyyy-MM-dd'T'HH:mm:ss.SSS`

**BridgeOpeningRecord Structure** (Historical Data):
```swift
struct BridgeOpeningRecord: Codable {
    let entitytype: String
    let entityname: String
    let entityid: String
    let opendatetime: String      // Historical opening time
    let closedatetime: String     // Historical closing time
    let minutesopen: String       // Historical duration
    let latitude: String
    let longitude: String
}
```

**Important Note**: This API provides **historical bridge opening data only**. No real-time bridge status or current opening/closing information is available from this endpoint.

### Cache Implementation

**Cache Metadata Fields**:
- `lastDataRefresh: Date?`
- `cacheExpirationTime: TimeInterval`
- `isOfflineMode: Bool`
- `lastSuccessfulFetch: Date?`

**Cache Strategy**:
1. Check cache first
2. If cache valid, return cached historical data
3. If cache invalid or missing, fetch historical data from network
4. On network success, update cache with historical data
5. On network failure, return stale historical cache if available

### Error Handling

**Network Errors**:
- Retry with exponential backoff
- Fallback to stale historical cache
- User-friendly error messages

**Data Errors**:
- Validate API response structure
- Handle missing or malformed historical data
- Graceful degradation

## Phase 3: HTTP Caching Optimization (Backlogged)

### Implementation Approach

**Phase 3 Changes are Minimal**:
- All changes live in `BridgeDataService.fetchFromNetwork()`
- No model/view changes required
- Leverages existing cache infrastructure

**HTTP Conditional GET Implementation**:
```swift
// 1. Read & send the last ETag
if let etag = UserDefaults.standard.string(forKey: "BridgeHistoryETag") {
    request.addValue(etag, forHTTPHeaderField: "If-None-Match")
}

// 2. Handle 304–Not-Modified
let (data, response) = try await URLSession.shared.data(for: request)
guard let http = response as? HTTPURLResponse else { throw … }
if http.statusCode == 304 {
    // return cached file
} else {
    // decode, cache, and save new ETag
    if let newEtag = http.value(forHTTPHeaderField: "Etag") {
        UserDefaults.standard.set(newEtag, forKey: "BridgeHistoryETag")
    }
    // ... existing processing
}
```

**Benefits**:
- Saves bandwidth when data hasn't changed
- Reduces API calls for Socrata's anonymous quota
- Improves performance for frequent polling scenarios
- Minimal code changes required

**When to Implement**:
- When increasing fetch frequency beyond twice daily
- When optimizing for bandwidth efficiency
- When preparing for production deployment

## Testing

**Unit Tests**: ✅ All passing
- Historical API integration tests
- Cache functionality tests
- Error handling tests
- Historical data validation tests

**Integration Tests**: ✅ All passing
- End-to-end historical data flow
- Cache persistence
- Network error scenarios

## Performance Considerations

- **Cache-first strategy** reduces network calls for historical data
- **@ObservationIgnored** prevents unnecessary UI updates
- **Exponential backoff** prevents API abuse
- **Background refresh** keeps historical data current
- **Phase 3**: HTTP conditional GET for bandwidth optimization

## Data Limitations

**Current Data Source Limitations**:
- **Historical data only**: No real-time bridge status
- **Past opening records**: Shows when bridges opened/closed in the past
- **No current status**: Cannot determine if a bridge is currently open or closed
- **No real-time updates**: Data is historical and does not update in real-time

**Future Considerations for Real-Time Data**:
- Would require different data sources for real-time bridge status
- May need integration with traffic APIs or municipal real-time systems
- Real-time data would require different architecture and update mechanisms

## Next Steps

### Immediate (Phase 2 Completion):
1. **Complete offline caching infrastructure**: Wire up disk caching, schedule twice-daily fetches, implement offline mode detection
2. **Add micro-UI improvements**: ProgressView, skeleton placeholders, error alerts with retry functionality
3. **Basic cache management UI**: Simple settings/preferences for cache control
4. **Foundation-first approach**: Ensure data layer is solid before major visual work

### Backlogged (Phase 3):
1. **HTTP caching optimization**: Implement ETag/If-None-Match for bandwidth efficiency
2. **Background fetch scheduling**: Optimize for twice-daily fetch pattern
3. **Real-time updates**: Explore options for current bridge status (if available)
4. **Core ML scoring**: Add machine learning for route optimization

### Future Enhancements (After Phase 2):
1. **Major visual polish**: Dashboard restyle with maps, charts, gauge rings
2. **HIG-compliant refinements**: Advanced animations and visual components
3. **Enhance historical analysis**: Add patterns and trends from historical data
4. **Optimize performance**: Add data compression and selective caching
5. **Add analytics**: Track usage patterns and performance metrics 
