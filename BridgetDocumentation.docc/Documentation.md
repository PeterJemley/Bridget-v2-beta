# Bridget

A SwiftUI app for Seattle bridge route optimization using historical data and real-time traffic analysis.

## Overview

Bridget is a route optimization app that helps users navigate Seattle's drawbridges by providing historical opening data and real-time traffic analysis. The app integrates with the Seattle Open Data API to fetch historical bridge opening records and uses machine learning for route optimization.

## Implementation Status

**For detailed implementation status, project phases, and progress tracking, see:**
- **Project Planning**: `Documentation/Seattle_Route_Optimization_Plan.md` - Complete implementation roadmap and status
- **Current Progress**: `Documentation/refinements-integration-summary.md` - Latest refinements integration status

### Quick Status Overview
- **Phase 1**: ✅ Historical Data Integration - COMPLETED
- **Phase 1.5**: ✅ Data Validation & Error Handling - COMPLETED  
- **Phase 2**: 🔄 Offline Caching - IN PROGRESS
- **Phase 2.5**: ✅ ML Training Data Pipeline - COMPLETED
- **Phase 3**: ⏸️ HTTP Caching Optimization - BACKLOGGED

## Business Validation and Data Quality

Bridget collects and reports all business validation failures encountered during data processing. See the validation documentation for details on validation failure reasons, their propagation, and API usage.

## Detailed Implementation Checklist

**For complete implementation details and checklists, see:**
- **Project Planning**: `Documentation/Seattle_Route_Optimization_Plan.md` - Comprehensive implementation checklists for all phases
- **Current Status**: `Documentation/refinements-integration-summary.md` - Latest refinements and integration status

This document focuses on API reference and technical documentation. Project planning and implementation tracking is maintained in the `Documentation/` folder.
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

## Documentation

For comprehensive documentation guidelines and progress tracking, see <doc:GradualDocumentationChecklist>.
