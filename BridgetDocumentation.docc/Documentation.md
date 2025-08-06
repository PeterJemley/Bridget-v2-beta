# Bridget

A SwiftUI app for Seattle bridge route optimization using historical data and real-time traffic analysis.

## Overview

Bridget is a route optimization app that helps users navigate Seattle's drawbridges by providing historical opening data and real-time traffic analysis. The app integrates with the Seattle Open Data API to fetch historical bridge opening records and uses machine learning for route optimization.

## Implementation Status

### Phase 1: Historical Data Integration ✅ **COMPLETED**
- [x] Successfully integrated with Seattle Open Data API: `https://data.seattle.gov/resource/gm8h-9449.json`
- [x] **Historical bridge opening data only** - no real-time bridge status available
- [x] Implemented proper JSON decoding for historical bridge opening records
- [x] Fixed date parsing to handle actual API format (`yyyy-MM-dd'T'HH:mm:ss.SSS`)
- [x] All tests passing with historical data
- [x] Cache infrastructure prepared for Phase 2

### Phase 1.5: Data Validation & Error Handling ✅ **COMPLETED**
- [x] Enhanced API response validation with Content-Type and payload size checks
- [x] Implemented comprehensive error classification with detailed diagnostics
- [x] Added business logic validation (bridge ID verification, date range filtering)
- [x] Centralized JSON decoder configuration with key/date strategies
- [x] Added debug logging for validation failures and skipped records
- [x] Comprehensive unit test coverage for all validation branches
- [x] Graceful degradation with detailed error context for production debugging

### Phase 2: Offline Caching **IN PROGRESS**
- [x] Cache metadata fields implemented with `@ObservationIgnored`
- [x] Cache serialization/deserialization ready
- [x] Retry logic with exponential backoff implemented
- [x] Cache-first strategy implemented
- [ ] Complete offline caching infrastructure
- [ ] Implement offline mode detection
- [ ] Implement background refresh
- [ ] Schedule twice-daily fetches
- [ ] Add basic cache management UI (settings/preferences)

### Phase 3: HTTP Caching Optimization **BACKLOGGED**
- [ ] HTTP conditional GET with ETag/If-None-Match headers
- [ ] 304 "Not Modified" response handling
- [ ] UserDefaults ETag storage
- [ ] Bandwidth optimization for frequent polling scenarios

## Detailed Implementation Checklist

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
  - [x] Error context preservation for debugging
  - [x] Comprehensive unit test coverage

### Phase 2: Offline Caching **IN PROGRESS**

- [x] **Cache infrastructure setup**
  - [x] Cache metadata fields with `@ObservationIgnored`
  - [x] Cache serialization/deserialization
  - [x] Retry logic with exponential backoff
  - [x] Cache-first strategy implementation

- [ ] **Complete offline caching infrastructure**
  - [ ] Implement offline mode detection
  - [ ] Implement background refresh
  - [ ] Schedule twice-daily fetches
  - [ ] Add basic cache management UI (settings/preferences)

- [ ] **Cache management features**
  - [ ] Cache size monitoring and cleanup
  - [ ] Cache expiration policies
  - [ ] Cache invalidation strategies
  - [ ] Cache performance metrics

### Phase 3: HTTP Caching Optimization **BACKLOGGED**

- [ ] **HTTP conditional requests**
  - [ ] ETag/If-None-Match header support
  - [ ] 304 "Not Modified" response handling
  - [ ] UserDefaults ETag storage
  - [ ] Bandwidth optimization

- [ ] **Advanced caching features**
  - [ ] Request batching and optimization
  - [ ] Response compression
  - [ ] Connection pooling
  - [ ] Cache warming strategies

### Phase 4: UI/UX Improvements **PLANNED**

- [ ] **Loading states and user feedback**
  - [ ] Add ProgressView during data loading
  - [ ] Add skeleton placeholders for route list items
  - [ ] Surface errors with standard SwiftUI .alert and retry button
  - [ ] Basic loading states for cache operations

- [ ] **Enhanced user experience**
  - [ ] Pull-to-refresh functionality
  - [ ] Offline indicators
  - [ ] Error recovery options
  - [ ] User preferences and settings

### Phase 5: Advanced Features **FUTURE**

- [ ] **Real-time integration**
  - [ ] Core ML model integration for traffic prediction
  - [ ] Real-time bridge status updates
  - [ ] Apple Maps slowdown integration
  - [ ] Route scoring algorithm improvements

- [ ] **Performance optimization**
  - [ ] Memory usage optimization
  - [ ] Background processing improvements
  - [ ] UI performance enhancements
  - [ ] Battery usage optimization

## Architecture Overview

### Core Components

**Models (Cache Ready)**
- <doc:AppStateModel>: Global state with cache metadata
- <doc:BridgeStatusModel>: Historical bridge data with cache support
- <doc:RouteModel>: Route representation with cache support

**Services (Complete + Cache Infrastructure)**
- <doc:BridgeDataService>: Historical API integration with caching
  - ✅ Historical Seattle API integration
  - ✅ Proper JSON decoding for historical records
  - ✅ Cache serialization/deserialization
  - ✅ Retry logic with exponential backoff
  - ✅ Cache-first strategy
  - 📋 Phase 3: HTTP conditional GET optimization

**Views (Historical Data Display)**
- <doc:RouteListView>: Displays historical bridge opening data
- <doc:ContentView>: Coordinates app state

## Technical Details

### API Integration

**Endpoint**: `https://data.seattle.gov/resource/gm8h-9449.json`
**Data Type**: **Historical bridge opening records only**
**Response Format**: Array of historical bridge opening records
**Date Format**: `yyyy-MM-dd'T'HH:mm:ss.SSS`

**BridgeOpeningRecord Structure** (Historical Data):
```json
{
  "entitytype": "Bridge",
  "entityname": "1st Ave South",
  "entityid": "1",
  "opendatetime": "2025-01-03T10:12:00.000",
  "closedatetime": "2025-01-03T10:20:00.000",
  "minutesopen": "8",
  "latitude": "47.542213439941406",
  "longitude": "-122.33446502685547"
}
```

### Bridge Identity Strategy

The system uses a **two-tier identification approach**:

1. **API Bridge IDs**: Numeric identifiers ("1", "2", "3", etc.) used for:
   - API validation and filtering
   - Record grouping during processing
   - Data integrity checks

2. **Business Bridge Names**: Human-readable names ("Fremont Bridge", "Ballard Bridge") used for:
   - Primary business identifier in `BridgeStatusModel`
   - User-facing operations and display
   - Route management and selection

### Error Handling Strategy

**NetworkError Types**:
- `networkError`: General network failures
- `invalidResponse`: Invalid HTTP response
- `httpError(statusCode:)`: HTTP status code errors
- `invalidContentType`: Wrong content type (expected JSON)
- `payloadSizeError`: Response too large or empty

**BridgeDataError Types**:
- `decodingError(DecodingError, rawData: Data)`: JSON parsing failures
- `processingError(String)`: Business logic processing errors

### Caching Strategy

**Cache-First Approach**:
1. Check cache for valid data
2. Return cached data if available and fresh
3. Fetch from network if cache is stale or missing
4. Update cache with new data
5. Fall back to sample data if all else fails

**Cache Metadata**:
- `lastUpdated`: Timestamp of last successful fetch
- `cacheExpiration`: Time-based cache invalidation
- `dataVersion`: Schema version for migration support

## Development Roadmap

### Immediate Priorities (Phase 2 Completion)
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

### Future Enhancements (Phase 3+)
- [ ] **HTTP Caching Optimization**
  - [ ] Add ETag/If-None-Match header support
  - [ ] Handle 304 "Not Modified" responses
  - [ ] Store ETags in UserDefaults
  - [ ] Optimize for bandwidth efficiency

- [ ] **Real-time Integration**
  - [ ] Core ML model integration for traffic prediction
  - [ ] Real-time bridge status updates
  - [ ] Apple Maps slowdown integration
  - [ ] Route scoring algorithm improvements

### Code Quality & Testing Roadmap
- [ ] **Enhanced testing coverage**
  - [ ] Integration tests for API scenarios
  - [ ] UI tests for user flows
  - [ ] Performance tests for caching
  - [ ] Error scenario testing

- [ ] **Code quality improvements**
  - [ ] Static analysis integration
  - [ ] Code coverage reporting
  - [ ] Documentation completeness
  - [ ] Performance profiling

## Code Quality & Best Practices

### State Management
- [x] **Use @Observable for reactive state management**
- [x] **Use @ObservationIgnored for non-reactive properties (e.g. timestamps, caches)**
- [x] **Implement proper error handling**
- [x] **Add comprehensive unit tests**
- [x] **Add file-level documentation**

### Performance Considerations
- [ ] **Profile on Device**: Use Instruments to watch for memory spikes during JSON decoding
- [ ] **Refine Observation Tracking**: Introduce withObservationTracking around hot loops (route scoring, data grouping)
- [ ] **Cache Optimization**: Implement proper cache eviction and size management

### Testing Strategy
- [x] **Unit Tests**: Comprehensive coverage for all service layers
- [ ] **Integration Tests**: Test real API integration and caching behavior
- [ ] **UI Tests**: Verify loading states, error handling, and user interactions

### Documentation Standards
- [x] **Code-level documentation**: Comprehensive doc comments for all public APIs
- [x] **Architecture documentation**: Detailed system design documentation
- [x] **Error handling documentation**: Complete error classification and recovery strategies
- [x] **Caching documentation**: Multi-level caching strategy and implementation details
- [ ] **User guide documentation**: End-user documentation and tutorials
- [ ] **API reference documentation**: Complete API reference with examples

## Getting Started

### For Users
Simply launch the app and it will automatically load historical bridge data. The app will display available routes and their optimization scores based on historical opening patterns.

### For Developers
1. **Clone the repository**
2. **Open Bridget.xcodeproj in Xcode**
3. **Build and run** on iOS Simulator or device
4. **View documentation** in Xcode's documentation browser

### For Testing
The app includes sample data providers that generate realistic mock data for testing scenarios without requiring network connectivity.

## Topics

### Essentials
- <doc:AppStateModel>
- <doc:BridgeStatusModel>
- <doc:RouteModel>

### Services
- <doc:BridgeDataService>
- <doc:NetworkClient>
- <doc:CacheService>
- <doc:BridgeDataProcessor>
- <doc:SampleDataProvider>

### Views
- <doc:RouteListView>
- <doc:ContentView>

### Architecture
- <doc:ArchitectureOverview>
- <doc:DataFlow>
- <doc:ErrorHandling>
- <doc:CachingStrategy>

### Development
- <doc:TestingWorkflow> 