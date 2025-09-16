# Bridget Technical Documentation

Welcome to the Bridget technical documentation. This documentation covers the architecture, implementation details, and technical deep-dives for the Bridget bridge monitoring and traffic prediction system.

## 🏗️ Architecture & Design

- **[Architecture Overview](ArchitectureOverview.md)** - System design, layers, and architectural decisions
- **[Data Flow](DataFlow.md)** - How data moves through the system from APIs to UI
- **[Error Handling](ErrorHandling.md)** - Comprehensive error classification and handling strategies

## 🔧 Implementation Details

### Concurrency & Thread Safety
- **[Concurrency Fixes](ConcurrencyFixes.md)** - Comprehensive overview of all concurrency fixes
- **[Thread Sanitizer Setup](Articles/ThreadSanitizer_Setup.md)** - Setup and usage guide for race detection

### Data Processing & Validation
- **[Data Processing Pipeline](DataProcessingPipeline.md)** - Core data transformation and processing
- **[Validation Failures](ValidationFailures.md)** - Data validation strategies and failure handling
- **[Validator Fixes](ValidatorFixes.md)** - Common validation issues and solutions

### ML & Training
- **[ML Training Data Pipeline](MLTrainingDataPipeline.md)** - Complete ML data generation pipeline
- **[On-Device Training Robustness](Articles/OnDeviceTrainingRobustness.md)** - Training implementation guide
- **[Baseline Metrics](Articles/BaselineMetrics.md)** - Performance metrics and safety net
- **[Dependency Recursion Workflow](Articles/DependencyRecursionWorkflow.md)** - Module extraction workflow

### Coordinate Systems
- **[Coordinate System Analysis](CoordinateSystemAnalysis.md)** - Coordinate system identification and analysis
- **[Coordinate Transformation Plan](CoordinateTransformationPlan.md)** - Transformation implementation plan

## 🧪 Testing & Development

- **[Testing Workflow](TestingWorkflow.md)** - Testing strategies and workflows
- **[Guard Statement Patterns](GuardStatementPatterns.md)** - Code patterns and best practices
- **[Caching Strategy](CachingStrategy.md)** - Caching implementation and strategies
- **[Statistics Utilities](StatisticsUtilitiesSummary.md)** - Statistical analysis utilities
- **[TransformMetrics Guide](TransformMetricsGuide.md)** - Comprehensive observability and accuracy tracking
- **[Accuracy Guard Enhancements](AccuracyGuardEnhancements.md)** - Enhanced accuracy validation with stratified assertions

## 👥 Public-Facing Documentation

- **[Data Reliability Guide](DataReliabilityGuide.md)** - User guide for data reliability and continuity
- **[Business Continuity Plan](BusinessContinuityPlan.md)** - Stakeholder documentation for business continuity
- **[Support Team Guide](SupportTeamGuide.md)** - Support team guide for explaining issues to users

## 📊 Project Management

For project management, roadmaps, and operational documentation, see the [Documentation/](../Documentation/) directory:

- **[Project Index](../Documentation/PROJECT_INDEX.md)** - Main project documentation index
- **[MultiPath Implementation Status](../Documentation/MultiPath_Implementation_Status.md)** - Implementation status and progress
- **[MultiPath Roadmap](../Documentation/MULTIPATH_ROADMAP.md)** - Development roadmap

## 🚀 Quick Start

1. **New to the project?** Start with [Architecture Overview](ArchitectureOverview.md)
2. **Working on concurrency?** Read [Concurrency Fixes](ConcurrencyFixes.md)
3. **Building ML features?** See [ML Training Data Pipeline](MLTrainingDataPipeline.md)
4. **Debugging validation?** Check [Validation Failures](ValidationFailures.md)
5. **Running tests?** Follow [Testing Workflow](TestingWorkflow.md)

## 📚 Related Documentation

- **[Project README](../../README.md)** - Project overview and quick start
- **[Documentation Structure](../Documentation/DOCUMENTATION_STRUCTURE.md)** - Documentation organization guide

---

**Last Updated**: 2025-09-04  
**Version**: Bridget v2.0  
**Owner**: @peterjemley
