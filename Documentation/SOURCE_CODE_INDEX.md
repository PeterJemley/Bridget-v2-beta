# Bridget Source Code Index

## 📱 Application Entry Point

### `BridgetApp.swift`
- **Purpose**: Main application entry point and configuration
- **Key Features**: App lifecycle management, environment setup, SwiftData schema configuration
- **Dependencies**: SwiftUI, Observation framework, SwiftData
- **File Size**: 5.6KB, 181 lines

## 🏗️ Models (Data Layer)

### Core Models
- **`AppStateModel.swift`** (16KB, 417 lines)
  - Global application state management
  - Navigation state and user preferences
  - Uses `@Observable` for reactive updates
  - Validation failure tracking and debugging

- **`BridgeStatusModel.swift`** (11KB, 277 lines)
  - Bridge opening/closing status data
  - Historical bridge event information
  - Real-time status updates

- **`RouteModel.swift`** (886B, 29 lines)
  - Route representation and optimization
  - Route scoring and preferences
  - Basic route structure

### ML and Data Models
- **`MLTypes.swift`** (34KB, 1007 lines)
  - Machine learning data types and structures
  - Core ML integration types
  - Training and inference data models

- **`BridgeEvent.swift`** (5.8KB, 181 lines)
  - Bridge opening/closing event data
  - Event timing and metadata
  - Event validation and processing

- **`ProbeTick.swift`** (4.3KB, 147 lines)
  - Traffic probe data points
  - Real-time traffic information
  - Data collection and processing

### Specialized Models
- **`RoutePreference.swift`** (10KB, 287 lines)
  - User route preferences and settings
  - Optimization parameters
  - User customization options

- **`BridgeTopologyModels.swift`** (10KB, 253 lines)
  - ML feature vector schema for bridge lift prediction
  - 14 standardized features for Core ML training
  - Schema contract between Swift and Python ML pipeline
  - `LiftFeatures` struct with `packedVector()` method

- **`TrafficProfile.swift`** (3.9KB, 126 lines)
  - SwiftData model for traffic profile management
  - Time-of-day multipliers (morning rush, evening rush, etc.)
  - Day-type multipliers (weekday/weekend)
  - Segment-type multipliers (arterial, highway, local)

- **`TrafficInferenceCache.swift`** (8.6KB, 268 lines)
  - Traffic inference result caching
  - Performance optimization
  - Memory management

- **`UserRouteHistory.swift`** (9.5KB, 334 lines)
  - User route history and preferences
  - Learning from user behavior
  - Personalization data

- **`BridgeTraffic.swift`** (2.2KB, 77 lines)
  - Traffic flow data models
  - Congestion patterns
  - Traffic analysis

- **`PipelineActivity.swift`** (698B, 35 lines)
  - Pipeline execution tracking
  - Activity monitoring
  - Performance metrics

- **`BridgeDataError.swift`** (995B, 34 lines)
  - Error types and handling
  - Error classification
  - User-friendly error messages

- **`SeattleDrawbridges.swift`** (7.8KB, 219 lines)
  - Canonical source for Seattle bridge information
  - Bridge ID validation and location lookups
  - Bridge metadata and spatial data

- **`Protocols.swift`** (6.0KB, 180 lines)
  - Protocol definitions for services
  - Interface contracts
  - Dependency injection support

## 🔧 Services (Business Logic Layer)

### Core Data Services
- **`BridgeDataService.swift`** (12KB, 345 lines)
  - Main data orchestration service
  - Coordinates data operations
  - Manages data flow between components

- **`BridgeDataProcessor.swift`** (5.2KB, 135 lines)
  - Data transformation and processing
  - Business logic implementation
  - Data validation coordination

- **`BridgeDataExporter.swift`** (21KB, 593 lines)
  - Data export functionality
  - Multiple format support
  - Export configuration management

### Machine Learning Services
- **`CoreMLTraining.swift`** (44KB, 1097 lines)
  - On-device ML training service
  - Apple Neural Engine integration
  - Training session management

- **`FeatureEngineeringService.swift`** (19KB, 469 lines)
  - ML feature extraction
  - Data preprocessing
  - Feature transformation

- **`MLPipelineBackgroundManager.swift`** (22KB, 721 lines)
  - Background ML pipeline management
  - Resource management
  - Performance optimization

- **`MLPipelineNotificationManager.swift`** (14KB, 394 lines)
  - ML pipeline notifications
  - User communication
  - Status updates

### Traffic Profile Services
- **`BasicTrafficProfileProvider.swift`** (7.7KB, 255 lines)
  - Traffic profile management with SwiftData
  - Time-of-day traffic modeling
  - Traffic multiplier calculations
  - Profile creation, activation, and deletion

### Validation and Quality Services
- **`DataValidationService.swift`** (43KB, 1164 lines)
  - Comprehensive data validation
  - Quality assurance
  - Error detection and reporting

- **`BridgeRecordValidator.swift`** (4.3KB, 122 lines)
  - Bridge record validation with geospatial checks
  - Business rule enforcement
  - Data integrity checks
  - Haversine distance validation

- **`ValidationTypes.swift`** (11KB, 334 lines)
  - Validation result types
  - Error classification
  - Validation metadata

- **`ValidationUtils.swift`** (1.2KB, 43 lines)
  - Validation utility functions
  - Common validation patterns
  - Reusable validation logic

### Pipeline and Validation Services
- **`PipelineParityValidator.swift`** (45KB, 1232 lines)
  - Pipeline validation
  - Consistency checking
  - Quality assurance

- **`PipelineValidationPluginSystem.swift`** (49KB, 1572 lines)
  - Plugin system for validation
  - Extensible validation
  - Custom validation rules

### Path Optimization Services
- **`PathScoringService.swift`** (Service for route scoring and optimization)
- **`MultiPath/`** (Directory containing multi-path optimization services)

### Infrastructure Services
- **`NetworkClient.swift`** (5.4KB, 183 lines)
  - HTTP networking with retry logic
  - API integration
  - Network error handling

- **`CacheService.swift`** (11KB, 321 lines)
  - Data caching and persistence
  - Cache invalidation
  - Performance optimization

- **`FileManagerUtils.swift`** (18KB, 501 lines)
  - Centralized file operations
  - Error handling
  - File system utilities

- **`RetryRecoveryService.swift`** (13KB, 440 lines)
  - Retry logic and recovery
  - Fault tolerance
  - Error recovery strategies

### Monitoring and Performance Services
- **`PerformanceMonitoringService.swift`** (13KB, 338 lines)
  - Performance monitoring
  - Metrics collection
  - Performance analysis

- **`PipelinePerformanceLogger.swift`** (11KB, 372 lines)
  - Pipeline performance logging
  - Performance metrics
  - Optimization insights

- **`DataStatisticsService.swift`** (32KB, 925 lines)
  - Statistical analysis
  - Data insights
  - Performance metrics

### Training and Preparation Services
- **`TrainPrepService.swift`** (21KB, 499 lines)
  - Training data preparation
  - Data preprocessing
  - Training pipeline setup

- **`EnhancedTrainPrepService.swift`** (20KB, 619 lines)
  - Enhanced training preparation
  - Advanced preprocessing
  - Quality improvements

- **`TrainingConfig.swift`** (8.5KB, 247 lines)
  - Training configuration
  - Parameter management
  - Configuration validation

### Specialized Services
- **`ProbeTickDataService.swift`** (15KB, 405 lines)
  - Probe data processing
  - Real-time data handling
  - Data quality management

- **`BridgeEventPersistenceService.swift`** (2.6KB, 77 lines)
  - Event persistence
  - Data storage
  - Retrieval optimization

- **`SampleDataProvider.swift`** (2.5KB, 81 lines)
  - Mock data generation
  - Testing support
  - Development assistance

### Utility Services
- **`DebugUtils.swift`** (248B, 13 lines)
  - Debug utilities
  - Development tools
  - Debugging assistance

- **`Extensions 2.swift`** (3.7KB, 96 lines)
  - Swift extensions for Date, Array, String
  - Safe array subscript implementation
  - Utility extensions

## 🎨 Views (Presentation Layer)

### Main Views
- **`ContentView.swift`** (5.5KB, 191 lines)
  - Root view coordinator
  - Main navigation structure
  - State management coordination

- **`RouteListView.swift`** (16KB, 484 lines)
  - Main route display interface
  - Route management
  - User interaction handling

### ML Pipeline Views
- **`MLPipelineTabView.swift`** (8.2KB, 296 lines)
  - ML pipeline management interface
  - Pipeline controls
  - Status monitoring

- **`PipelineMetricsDashboard.swift`** (23KB, 764 lines)
  - Pipeline performance monitoring
  - Real-time metrics
  - Performance analysis

- **`PipelinePluginManagementView.swift`** (16KB, 576 lines)
  - Plugin management interface
  - Configuration management
  - Plugin controls

### Bridge and Traffic Views
- **`BridgeStatusView.swift`** (2.1KB, 85 lines)
  - Bridge status display
  - Real-time updates
  - Status information

- **`TrafficAlertsView.swift`** (3.0KB, 115 lines)
  - Traffic alert notifications
  - Alert management
  - User notifications

### Pipeline Management Views
- **`PipelineTroubleshootingView.swift`** (3.8KB, 122 lines)
  - Pipeline troubleshooting
  - Error diagnosis
  - Problem resolution

- **`PipelineSettingsView.swift`** (2.7KB, 86 lines)
  - Pipeline configuration
  - Settings management
  - Parameter adjustment

- **`PipelineStatusRow.swift`** (1.3KB, 50 lines)
  - Pipeline status display
  - Status indicators
  - Quick status overview

- **`PipelineStatusCard.swift`** (2.3KB, 79 lines)
  - Pipeline status cards
  - Visual status representation
  - Status details

- **`PipelineDocumentationView.swift`** (2.0KB, 62 lines)
  - Pipeline documentation
  - Help and guidance
  - User assistance

### Export and Configuration Views
- **`ExportConfigurationSheet.swift`** (1.5KB, 51 lines)
  - Export configuration
  - Export settings
  - Configuration management

- **`ExportHistoryView.swift`** (4.2KB, 142 lines)
  - Export history
  - Export tracking
  - History management

- **`CalibrationView.swift`** (2.7KB, 90 lines)
  - System calibration
  - Calibration controls
  - Accuracy adjustment

### User Experience Views
- **`MyRoutesView.swift`** (2.7KB, 117 lines)
  - User route management
  - Personal routes
  - Route customization

- **`RecentActivityView.swift`** (2.4KB, 105 lines)
  - Recent activity display
  - Activity tracking
  - User engagement

- **`QuickActionsView.swift`** (3.0KB, 101 lines)
  - Quick actions
  - Shortcuts
  - User efficiency

- **`SettingsTabView.swift`** (1.3KB, 42 lines)
  - Application settings
  - Configuration management
  - User preferences
  - Developer mode integration

- **`TrafficProfileManagementView.swift`** (Traffic profile management interface)

## 🔄 ViewModels (State Management)

### Core ViewModels
- **`AppStateViewModel.swift`** (View model for application state)
- **`RouteViewModel.swift`** (View model for route management)
- **`BridgeStatusViewModel.swift`** (View model for bridge status)
- **`MLPipelineViewModel.swift`** (View model for ML pipeline)
- **`ValidationViewModel.swift`** (View model for validation)
- **`ExportViewModel.swift`** (View model for export functionality)

## 🔌 Extensions (Swift Extensions)

### Swift Extensions
- **`Extensions/`** (Directory containing Swift extensions)
  - **`JSONDecoder+Bridge.swift`** (Centralized JSON decoding utilities)
  - **`JSONEncoder+Bridge.swift`** (Centralized JSON encoding utilities)

## 📊 Data and Configuration

### Configuration Files
- **`Info.plist`** (611B, 21 lines)
  - Application configuration
  - Bundle information
  - System requirements

- **`Bridget.entitlements`** (287B, 9 lines)
  - Application capabilities
  - System permissions
  - Security settings

### Data Files
- **`seattle_drawbridges.topology.json`** (1.7KB, 54 lines)
  - Bridge topology data
  - Spatial relationships
  - Network structure

## 🧪 Testing (Test Suite)

### Core Tests
- **`BridgetTests.swift`** - Main test suite
- **`BridgeDataProcessorTests.swift`** - Data processing tests
- **`CoreMLTrainingTests.swift`** - ML training tests
- **`DataValidationTests.swift`** - Validation logic tests
- **`PathScoringServiceTests.swift`** - Path optimization tests
- **`MultiPathTypesTests.swift`** - Multi-path type tests
- **`BridgeRecordValidatorTests.swift`** - Record validation tests
- **`FeatureEngineeringTests.swift`** - Feature extraction tests
- **`FileManagerUtilsTests.swift`** - File operations tests
- **`PipelineParityValidatorTests.swift`** - Pipeline validation tests
- **`SeattleDrawbridgesTests.swift`** - Bridge data tests
- **`ThreadSanitizerTests.swift`** - Thread safety tests
- **`BasicTrafficProfileProviderTests.swift`** - Traffic profile provider tests
- **`ValidationFailureDiagnosticTest.swift`** - Validation failure diagnostics

### Test Resources
- **`TestResources/`** - Test data and fixtures
- **`VerifyAPIandSchema.playground/`** - API verification playground

## 📚 Documentation

### Technical Documentation
- **`BridgetDocumentation.docc/`** - DocC technical documentation
- **`Documentation/`** - Project management documentation
- **`README.md`** - Project overview and progress

## 🔧 Build and Configuration

### Build Configuration
- **`Package.swift`** (626B, 16 lines)
  - Swift package configuration
  - Dependencies
  - Build targets

- **`.swiftlint.yml`** (2.6KB, 111 lines)
  - SwiftLint configuration
  - Code quality rules
  - Style guidelines

- **`.swiftformat`** (832B, 21 lines)
  - SwiftFormat configuration
  - Code formatting rules
  - Style preferences

## 📁 Directory Structure Summary

```
Bridget/
├── BridgetApp.swift              # App entry point
├── Models/                       # 16 files - Data models
├── Services/                     # 42 files - Business logic
├── Views/                        # 20 files - User interface
├── ViewModels/                   # 6 files - State management
├── Extensions/                   # 2 files - Swift extensions
├── Assets.xcassets/              # App resources
├── Documentation/                # App-specific docs
└── Configuration files           # Info.plist, entitlements, etc.

BridgetTests/                     # 40+ test files
BridgetDocumentation.docc/        # 20+ technical docs
Documentation/                    # 10+ project docs
Scripts/                         # 6 utility scripts
```

## 🔗 Key Relationships

### Data Flow
1. **Models** define data structures
2. **Services** process and transform data
3. **ViewModels** manage state and coordinate
4. **Views** present data to users

### Service Dependencies
- **BridgeDataService** orchestrates other services
- **CoreMLTraining** depends on **FeatureEngineeringService**
- **DataValidationService** validates data from multiple sources
- **CacheService** provides caching for multiple services
- **BasicTrafficProfileProvider** integrates with **ETAEstimator**

### View Hierarchy
- **ContentView** is the root coordinator
- **SettingsTabView** manages settings and developer tools
- **RouteListView** displays route information
- **PipelineMetricsDashboard** shows performance data

### ML Pipeline Integration
- **BridgeTopologyModels** provides schema for Python ML training
- **BasicTrafficProfileProvider** applies traffic multipliers to ETA calculations
- **CoreMLTraining** handles on-device model training
- **FeatureEngineeringService** processes raw data into ML features

---

*This index provides a comprehensive overview of all source code files in the Bridget project. For detailed implementation information, refer to the individual source files and their associated documentation.*

