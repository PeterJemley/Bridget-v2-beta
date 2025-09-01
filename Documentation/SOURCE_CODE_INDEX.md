# Bridget Source Code Index

## 📱 Application Entry Point

### `BridgetApp.swift`
- **Purpose**: Main application entry point and configuration
- **Key Features**: App lifecycle management, environment setup
- **Dependencies**: SwiftUI, Observation framework
- **File Size**: 5.6KB, 181 lines

## 🏗️ Models (Data Layer)

### Core Models
- **`AppStateModel.swift`** (12KB, 353 lines)
  - Global application state management
  - Navigation state and user preferences
  - Uses `@Observable` for reactive updates

- **`BridgeStatusModel.swift`** (11KB, 277 lines)
  - Bridge opening/closing status data
  - Historical bridge event information
  - Real-time status updates

- **`RouteModel.swift** (886B, 29 lines)
  - Route representation and optimization
  - Route scoring and preferences
  - Basic route structure

### ML and Data Models
- **`MLTypes.swift`** (34KB, 1001 lines)
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
- **`RoutePreference.swift`** (10KB, 279 lines)
  - User route preferences and settings
  - Optimization parameters
  - User customization options

- **`BridgeTopologyModels.swift`** (10KB, 253 lines)
  - Bridge network topology representation
  - Graph structure for pathfinding
  - Spatial relationships

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

- **`PipelineActivity.swift`** (699B, 36 lines)
  - Pipeline execution tracking
  - Activity monitoring
  - Performance metrics

- **`BridgeDataError.swift`** (995B, 34 lines)
  - Error types and handling
  - Error classification
  - User-friendly error messages

## 🔧 Services (Business Logic Layer)

### Core Data Services
- **`BridgeDataService.swift`** (12KB, 326 lines)
  - Main data orchestration service
  - Coordinates data operations
  - Manages data flow between components

- **`BridgeDataProcessor.swift`** (5.0KB, 122 lines)
  - Data transformation and processing
  - Business logic implementation
  - Data validation coordination

- **`BridgeDataExporter.swift`** (20KB, 559 lines)
  - Data export functionality
  - Multiple format support
  - Export configuration management

### Machine Learning Services
- **`CoreMLTraining.swift`** (43KB, 1077 lines)
  - On-device ML training service
  - Apple Neural Engine integration
  - Training session management

- **`FeatureEngineeringService.swift`** (19KB, 456 lines)
  - ML feature extraction
  - Data preprocessing
  - Feature transformation

- **`MLPipelineBackgroundManager.swift`** (15KB, 477 lines)
  - Background ML pipeline management
  - Resource management
  - Performance optimization

- **`MLPipelineNotificationManager.swift`** (14KB, 334 lines)
  - ML pipeline notifications
  - User communication
  - Status updates

### Validation and Quality Services
- **`DataValidationService.swift`** (42KB, 1060 lines)
  - Comprehensive data validation
  - Quality assurance
  - Error detection and reporting

- **`BridgeRecordValidator.swift`** (2.5KB, 70 lines)
  - Bridge record validation
  - Business rule enforcement
  - Data integrity checks

- **`ValidationTypes.swift`** (11KB, 304 lines)
  - Validation result types
  - Error classification
  - Validation metadata

- **`ValidationUtils.swift`** (1.2KB, 41 lines)
  - Validation utility functions
  - Common validation patterns
  - Reusable validation logic

### Path Optimization Services
- **`PathScoringService.swift** (Service for route scoring and optimization)
- **`MultiPath/`** (Directory containing multi-path optimization services)

### Infrastructure Services
- **`NetworkClient.swift`** (5.4KB, 178 lines)
  - HTTP networking with retry logic
  - API integration
  - Network error handling

- **`CacheService.swift`** (7.6KB, 241 lines)
  - Data caching and persistence
  - Cache invalidation
  - Performance optimization

- **`FileManagerUtils.swift`** (15KB, 394 lines)
  - Centralized file operations
  - Error handling
  - File system utilities

- **`RetryRecoveryService.swift`** (12KB, 388 lines)
  - Retry logic and recovery
  - Fault tolerance
  - Error recovery strategies

### Monitoring and Performance Services
- **`PerformanceMonitoringService.swift`** (12KB, 306 lines)
  - Performance monitoring
  - Metrics collection
  - Performance analysis

- **`PipelinePerformanceLogger.swift`** (11KB, 347 lines)
  - Pipeline performance logging
  - Performance metrics
  - Optimization insights

- **`DataStatisticsService.swift`** (30KB, 810 lines)
  - Statistical analysis
  - Data insights
  - Performance metrics

### Training and Preparation Services
- **`TrainPrepService.swift`** (21KB, 498 lines)
  - Training data preparation
  - Data preprocessing
  - Training pipeline setup

- **`EnhancedTrainPrepService.swift`** (19KB, 538 lines)
  - Enhanced training preparation
  - Advanced preprocessing
  - Quality improvements

- **`TrainingConfig.swift`** (8.5KB, 246 lines)
  - Training configuration
  - Parameter management
  - Configuration validation

### Specialized Services
- **`ProbeTickDataService.swift`** (14KB, 366 lines)
  - Probe data processing
  - Real-time data handling
  - Data quality management

- **`BridgeEventPersistenceService.swift`** (2.6KB, 77 lines)
  - Event persistence
  - Data storage
  - Retrieval optimization

- **`SampleDataProvider.swift`** (2.5KB, 80 lines)
  - Mock data generation
  - Testing support
  - Development assistance

### Pipeline and Validation Services
- **`PipelineParityValidator.swift`** (43KB, 1139 lines)
  - Pipeline validation
  - Consistency checking
  - Quality assurance

- **`PipelineValidationPluginSystem.swift`** (47KB, 1382 lines)
  - Plugin system for validation
  - Extensible validation
  - Custom validation rules

### Utility Services
- **`DebugUtils.swift`** (248B, 13 lines)
  - Debug utilities
  - Development tools
  - Debugging assistance

- **`TestSupport.swift`** (217B, 10 lines)
  - Testing support utilities
  - Test helper functions
  - Testing assistance

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

- **`RouteListView.swift`** (16KB, 484 lines)
  - Route list display
  - Route management
  - User interaction

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
  - **`Extensions.swift`** (General Swift extensions)
  - **`Extensions 2.swift`** (Additional extensions)
  - **`Extensions 3.swift`** (More extensions)

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
├── Models/                       # 15 files - Data models
├── Services/                     # 42 files - Business logic
├── Views/                        # 19 files - User interface
├── ViewModels/                   # 6 files - State management
├── Extensions/                   # 3 files - Swift extensions
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

### View Hierarchy
- **ContentView** is the root coordinator
- **MLPipelineTabView** manages ML pipeline views
- **RouteListView** displays route information
- **PipelineMetricsDashboard** shows performance data

---

*This index provides a comprehensive overview of all source code files in the Bridget project. For detailed implementation information, refer to the individual source files and their associated documentation.*

