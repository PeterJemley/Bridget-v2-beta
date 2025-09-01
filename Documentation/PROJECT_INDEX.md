# Bridget Project Index

## 🏗️ Project Overview
**Bridget** is a SwiftUI application for monitoring bridge openings in Seattle using Apple's Observation framework and Core ML for on-device machine learning. The project follows a modular, service-oriented architecture with comprehensive testing and documentation.

## 📁 Project Structure

### Core Application (`Bridget/`)
```
Bridget/
├── BridgetApp.swift              # Main app entry point
├── Assets.xcassets/              # App icons and colors
├── Info.plist                    # App configuration
├── Bridget.entitlements          # App capabilities
├── seattle_drawbridges.topology.json  # Bridge topology data
├── Models/                       # Data models and business logic
├── Services/                     # Core business services
├── Views/                        # SwiftUI user interface
├── ViewModels/                   # View state management
├── Extensions/                   # Swift extensions
└── Documentation/                # App-specific documentation
```

### Documentation (`BridgetDocumentation.docc/`)
```
BridgetDocumentation.docc/
├── README.md                     # Technical documentation overview
├── ArchitectureOverview.md       # System architecture and design
├── DataFlow.md                   # Data flow patterns and pipelines
├── DataProcessingPipeline.md     # Data processing implementation
├── ErrorHandling.md              # Error handling patterns
├── MLTrainingDataPipeline.md     # ML pipeline technical docs
├── MLTrainingDataPipelineOverview.md  # ML pipeline overview
├── MLTrainingDataPipeline.catalog     # ML pipeline examples
├── CachingStrategy.md            # Caching implementation
├── FileManagerUtils.md           # File operations utilities
├── ValidationFailures.md         # Data validation handling
├── GuardStatementPatterns.md     # Validation pattern refactoring
├── TestingWorkflow.md            # Testing procedures
├── StatisticsUtilitiesSummary.md # Statistical analysis tools
├── MultiPath_Implementation_Status.md  # Path optimization status
├── GradualDocumentationChecklist.md    # Documentation progress
├── SurfacesValidationFailures.md # Surface validation issues
└── ValidatorFixes.md             # Validation fixes and improvements
```

### Testing (`BridgetTests/`)
```
BridgetTests/
├── BridgetTests.swift            # Core test suite
├── BridgeDataProcessorTests.swift # Data processing tests
├── CoreMLTrainingTests.swift     # ML training tests
├── DataValidationTests.swift     # Validation logic tests
├── PathScoringServiceTests.swift # Path optimization tests
├── MultiPathTypesTests.swift     # Multi-path type tests
├── BridgeRecordValidatorTests.swift # Record validation tests
├── FeatureEngineeringTests.swift # Feature extraction tests
├── FileManagerUtilsTests.swift   # File operations tests
├── PipelineParityValidatorTests.swift # Pipeline validation tests
├── SeattleDrawbridgesTests.swift # Bridge data tests
├── ThreadSanitizerTests.swift    # Thread safety tests
├── TestResources/                # Test data and fixtures
└── VerifyAPIandSchema.playground/ # API verification playground
```

### Project Management (`Documentation/`)
```
Documentation/
├── README.md                     # Project overview and progress
├── baseline-metrics.md           # Performance baseline metrics
├── Bridge_Validation_Evaluation.md # Validation evaluation results
├── contracts.md                  # API contracts and interfaces
├── dependency-recursion-workflow.md # Dependency management
├── DOCUMENTATION_STRUCTURE.md    # Documentation organization
├── OnDeviceTrainingRobustness.md # Training robustness guide
├── Seattle_Route_Optimization_Plan.md # Route optimization planning
├── ThreadSanitizer_Setup.md      # Thread sanitizer configuration
└── clean_simulator.sh            # Simulator cleanup script
```

### Scripts and Tools (`Scripts/`)
```
Scripts/
├── README.md                     # Scripts documentation
├── collect_golden_samples.swift  # Sample data collection
├── run_baseline_test.swift       # Baseline performance testing
├── run_exporter.swift            # Data export utilities
├── run_tsan_tests.sh            # Thread sanitizer testing
└── train_prep.py                # Python training preparation
```

## 🎯 Key Components

### Models
- **`AppStateModel.swift`** - Global application state and navigation
- **`BridgeStatusModel.swift`** - Bridge data with historical information
- **`RouteModel.swift`** - Route representation and optimization
- **`MLTypes.swift`** - Machine learning data types and structures
- **`BridgeEvent.swift`** - Bridge opening/closing events
- **`ProbeTick.swift`** - Traffic probe data points

### Services
- **`BridgeDataService.swift`** - Main data orchestration service
- **`CoreMLTraining.swift`** - On-device ML training service
- **`DataValidationService.swift`** - Data quality validation
- **`FeatureEngineeringService.swift`** - ML feature extraction
- **`PathScoringService.swift`** - Route optimization and scoring
- **`CacheService.swift`** - Data caching and persistence
- **`NetworkClient.swift`** - HTTP networking with retry logic
- **`FileManagerUtils.swift`** - Centralized file operations

### Views
- **`ContentView.swift`** - Root view coordinator
- **`RouteListView.swift`** - Main route display interface
- **`PipelineMetricsDashboard.swift`** - ML pipeline monitoring
- **`MLPipelineTabView.swift`** - ML pipeline management
- **`BridgeStatusView.swift`** - Bridge status display
- **`TrafficAlertsView.swift`** - Traffic alert notifications

## 🚀 Key Features

### Core Functionality
- **Real-time Bridge Monitoring** - Live Seattle bridge opening status
- **Route Optimization** - ML-powered route scoring and optimization
- **On-Device ML** - Core ML training using Apple Neural Engine
- **Reactive UI** - SwiftUI with Observation framework

### Technical Capabilities
- **Modular Architecture** - Clean separation of concerns
- **Comprehensive Testing** - 90%+ test coverage
- **Data Validation** - Robust data quality assurance
- **Caching Strategy** - Cache-first with graceful degradation
- **Error Handling** - Comprehensive error classification
- **Performance Monitoring** - Real-time pipeline metrics

## 📚 Documentation Navigation

### For Developers
1. **Start Here**: `BridgetDocumentation.docc/README.md`
2. **Architecture**: `BridgetDocumentation.docc/ArchitectureOverview.md`
3. **Data Flow**: `BridgetDocumentation.docc/DataFlow.md`
4. **Implementation**: `BridgetDocumentation.docc/DataProcessingPipeline.md`

### For ML Engineers
1. **ML Overview**: `BridgetDocumentation.docc/MLTrainingDataPipelineOverview.md`
2. **Technical Details**: `BridgetDocumentation.docc/MLTrainingDataPipeline.md`
3. **Examples**: `BridgetDocumentation.docc/MLTrainingDataPipeline.catalog`

### For Testers
1. **Testing Workflow**: `BridgetDocumentation.docc/TestingWorkflow.md`
2. **Test Suite**: `BridgetTests/` directory
3. **Test Resources**: `BridgetTests/TestResources/`

### For Project Managers
1. **Project Overview**: `README.md`
2. **Progress Tracking**: `Documentation/README.md`
3. **Implementation Status**: `BridgetDocumentation.docc/MultiPath_Implementation_Status.md`

## 🔧 Development Setup

### Requirements
- **Platform**: macOS 13.0+
- **Swift**: 5.9+
- **Xcode**: Latest stable version
- **Dependencies**: SwiftLint, SwiftFormat

### Key Dependencies
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/realm/SwiftLint.git", from: "0.50.0"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat.git", from: "0.51.0")
]
```

### Build and Test
```bash
# Build the project
xcodebuild -project Bridget.xcodeproj -scheme Bridget build

# Run tests
xcodebuild -project Bridget.xcodeproj -scheme Bridget test

# Run thread sanitizer tests
./Scripts/run_tsan_tests.sh
```

## 📊 Project Status

### ✅ Completed Modules
- Core ML Training Module (Production Ready)
- Data Validation Module
- Feature Engineering Module
- Guard Statement Patterns Refactoring
- File Manager Operations Refactoring
- MultiPath Traffic Prediction System (Phase 3)

### 🔄 In Progress
- **MultiPath Phase 11**: Performance benchmarking with Seattle dataset, traffic profile integration
- Advanced uncertainty quantification (Phase 4 planning)
- Enhanced statistical analysis
- Performance optimizations

### 📋 Future Roadmap
- **MultiPath Phase 11-13**: Performance benchmarking, ML integration, production deployment
- Ensemble methods for route prediction
- Advanced ML model architectures
- Real-time traffic integration
- Enhanced user experience features

**📖 Detailed Roadmap**: See `MULTIPATH_ROADMAP.md` for comprehensive MultiPath implementation plan

## 🐛 Known Issues and Solutions

### Validation Failures
- **Documentation**: `BridgetDocumentation.docc/ValidationFailures.md`
- **Solutions**: `BridgetDocumentation.docc/ValidatorFixes.md`
- **Surface Issues**: `BridgetDocumentation.docc/SurfacesValidationFailures.md`

### Thread Safety
- **Setup Guide**: `Documentation/ThreadSanitizer_Setup.md`
- **Tests**: `BridgetTests/ThreadSanitizerTests.swift`

## 🤝 Contributing

### Code Standards
- **SwiftLint**: Automated code quality checks
- **SwiftFormat**: Automated code formatting
- **Testing**: Comprehensive test coverage required
- **Documentation**: DocC-compatible markdown

### Development Workflow
1. Follow modular architecture principles
2. Write comprehensive tests for new features
3. Update relevant documentation
4. Ensure thread safety and error handling
5. Maintain backward compatibility

---

*This index provides a comprehensive overview of the Bridget project. For specific implementation details, refer to the individual documentation files and source code.*
