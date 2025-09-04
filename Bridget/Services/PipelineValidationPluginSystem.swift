import Foundation
import OSLog
import Observation

// MARK: - Plugin Protocol

/// Protocol for custom pipeline validators that can be registered and executed
public protocol PipelineValidator {
    /// Unique name identifier for the validator
    var name: String { get }

    /// Description of what this validator checks
    var description: String { get }

    /// Whether this validator is enabled
    var isEnabled: Bool { get set }

    /// Priority level for execution order (lower numbers execute first)
    var priority: Int { get }

    /// Validate raw probe tick data
    /// - Parameter ticks: Array of raw probe ticks to validate
    /// - Returns: Validation result with errors and warnings
    func validate(ticks: [ProbeTickRaw]) -> DataValidationResult

    /// Validate feature vectors
    /// - Parameter features: Array of feature vectors to validate
    /// - Returns: Validation result with errors and warnings
    func validate(features: [FeatureVector]) -> DataValidationResult

    /// Validate model performance metrics
    /// - Parameter metrics: Model performance metrics to validate
    /// - Returns: Validation result with errors and warnings
    func validate(metrics: ModelPerformanceMetrics) -> DataValidationResult

    /// Get configuration options for this validator
    /// - Returns: Dictionary of configurable parameters
    func getConfiguration() -> [String: Any]

    /// Update configuration for this validator
    /// - Parameter config: New configuration parameters
    mutating func updateConfiguration(_ config: [String: Any]) throws

    /// Generate statistics artifacts (optional)
    /// - Parameter ticks: Array of raw probe ticks
    /// - Returns: Statistics artifacts if supported, nil otherwise
    func generateStatistics(from ticks: [ProbeTickRaw]) -> BridgeDataStatistics?

    /// Generate statistics artifacts (optional)
    /// - Parameter features: Array of feature vectors
    /// - Returns: Statistics artifacts if supported, nil otherwise
    func generateStatistics(from features: [FeatureVector])
        -> BridgeDataStatistics?
}

// MARK: - Plugin Manager

/// Manages custom validation plugins for the ML pipeline
@MainActor
@Observable
public class PipelineValidationPluginManager {
    /// Registered validators
    public private(set) var validators: [PipelineValidator] = []

    /// Validation results from the last run
    public private(set) var lastValidationResults:
        [String: DataValidationResult] = [:]

    /// Statistics artifacts from the last run
    public private(set) var lastStatisticsArtifacts:
        [String: BridgeDataStatistics] = [:]

    /// Whether plugins are enabled
    public var pluginsEnabled = true

    /// Logger for plugin operations
    private let logger = Logger(
        subsystem: "com.bridget.pipeline",
        category: "ValidationPlugins"
    )

    /// Statistics service for generating comprehensive artifacts
    private let statisticsService = DataStatisticsService()

    public init() {
        logger.info("Pipeline Validation Plugin Manager initialized")
    }

    // MARK: - Plugin Registration

    /// Register a new validator plugin
    /// - Parameter validator: The validator to register
    public func registerValidator(_ validator: PipelineValidator) {
        // Check if validator with same name already exists
        if validators.contains(where: { $0.name == validator.name }) {
            logger.warning(
                "Validator '\(validator.name)' already registered, replacing existing one"
            )
            validators.removeAll { $0.name == validator.name }
        }

        validators.append(validator)
        validators.sort { $0.priority < $1.priority }

        logger.info(
            "Registered validator '\(validator.name)' with priority \(validator.priority)"
        )
    }

    /// Unregister a validator plugin
    /// - Parameter name: Name of the validator to unregister
    public func unregisterValidator(named name: String) {
        validators.removeAll { $0.name == name }
        logger.info("Unregistered validator '\(name)'")
    }

    /// Get a validator by name
    /// - Parameter name: Name of the validator to retrieve
    /// - Returns: The validator if found, nil otherwise
    public func getValidator(named name: String) -> PipelineValidator? {
        return validators.first { $0.name == name }
    }

    /// Enable or disable a specific validator
    /// - Parameters:
    ///   - name: Name of the validator
    ///   - enabled: Whether to enable or disable
    public func setValidator(_ name: String, enabled: Bool) {
        if var validator = getValidator(named: name) {
            validator.isEnabled = enabled
            logger.info("Set validator '\(name)' enabled: \(enabled)")
        }
    }

    // MARK: - Validation Execution

    /// Run all enabled validators on probe tick data
    /// - Parameter ticks: Array of probe ticks to validate
    /// - Returns: Combined validation results and statistics artifacts
    public func validateAll(ticks: [ProbeTickRaw]) -> (
        results: [String: DataValidationResult],
        artifacts: [String: BridgeDataStatistics]
    ) {
        if !pluginsEnabled {
            logger.info("Plugins disabled, skipping validation")
            return ([:], [:])
        }

        var results: [String: DataValidationResult] = [:]
        var artifacts: [String: BridgeDataStatistics] = [:]

        for validator in validators where validator.isEnabled {
            logger.info(
                "Running validator '\(validator.name)' on \(ticks.count) ticks"
            )

            let result = validator.validate(ticks: ticks)
            results[validator.name] = result

            // Generate statistics artifacts if supported
            if let statistics = validator.generateStatistics(from: ticks) {
                artifacts[validator.name] = statistics
                logger.info(
                    "Generated statistics artifacts for validator '\(validator.name)'"
                )
            }
        }

        lastValidationResults = results
        lastStatisticsArtifacts = artifacts

        logger.info(
            "Validation complete: \(results.count) validators, \(artifacts.count) artifacts"
        )
        return (results, artifacts)
    }

    /// Run all enabled validators on feature vectors
    /// - Parameter features: Array of feature vectors to validate
    /// - Returns: Combined validation results and statistics artifacts
    public func validateAll(features: [FeatureVector]) -> (
        results: [String: DataValidationResult],
        artifacts: [String: BridgeDataStatistics]
    ) {
        if !pluginsEnabled {
            logger.info("Plugins disabled, skipping validation")
            return ([:], [:])
        }

        var results: [String: DataValidationResult] = [:]
        var artifacts: [String: BridgeDataStatistics] = [:]

        for validator in validators where validator.isEnabled {
            logger.info(
                "Running validator '\(validator.name)' on \(features.count) features"
            )

            let result = validator.validate(features: features)
            results[validator.name] = result

            // Generate statistics artifacts if supported
            if let statistics = validator.generateStatistics(from: features) {
                artifacts[validator.name] = statistics
                logger.info(
                    "Generated statistics artifacts for validator '\(validator.name)'"
                )
            }
        }

        lastValidationResults = results
        lastStatisticsArtifacts = artifacts

        logger.info(
            "Validation complete: \(results.count) validators, \(artifacts.count) artifacts"
        )
        return (results, artifacts)
    }

    /// Run all enabled validators on model metrics
    /// - Parameter metrics: Model performance metrics to validate
    /// - Returns: Combined validation results
    public func validateAll(metrics: ModelPerformanceMetrics) -> [String:
        DataValidationResult]
    {
        if !pluginsEnabled {
            logger.info("Plugins disabled, skipping validation")
            return [:]
        }

        var results: [String: DataValidationResult] = [:]

        for validator in validators where validator.isEnabled {
            logger.info(
                "Running validator '\(validator.name)' on model metrics"
            )

            let result = validator.validate(metrics: metrics)
            results[validator.name] = result
        }

        lastValidationResults = results

        logger.info("Validation complete: \(results.count) validators")
        return results
    }

    // MARK: - Statistics Generation

    /// Generate comprehensive statistics for probe tick data
    /// - Parameter ticks: Array of probe ticks
    /// - Returns: Complete statistics including bridge, time, and horizon analysis
    public func generateComprehensiveStatistics(from ticks: [ProbeTickRaw])
        -> BridgeDataStatistics
    {
        logger.info(
            "Generating comprehensive statistics for \(ticks.count) ticks"
        )
        return statisticsService.generateStatistics(from: ticks)
    }

    /// Generate comprehensive statistics for feature vectors
    /// - Parameter features: Array of feature vectors
    /// - Returns: Complete statistics including bridge, time, and horizon analysis
    public func generateComprehensiveStatistics(from features: [FeatureVector])
        -> BridgeDataStatistics
    {
        logger.info(
            "Generating comprehensive statistics for \(features.count) features"
        )
        return statisticsService.generateStatistics(from: features)
    }

    /// Export statistics to JSON format
    /// - Parameter statistics: The statistics to export
    /// - Returns: JSON string representation
    public func exportStatisticsToJSON(_ statistics: BridgeDataStatistics)
        throws -> String
    {
        return try statisticsService.exportToJSON(statistics)
    }

    /// Export statistics to CSV format
    /// - Parameter statistics: The statistics to export
    /// - Returns: CSV string representation
    public func exportStatisticsToCSV(_ statistics: BridgeDataStatistics)
        -> String
    {
        return statisticsService.exportToCSV(statistics)
    }

    /// Export horizon coverage to CSV format
    /// - Parameter statistics: The statistics to export
    /// - Returns: CSV string representation of horizon coverage
    public func exportHorizonCoverageToCSV(_ statistics: BridgeDataStatistics)
        -> String
    {
        return statisticsService.exportHorizonCoverageToCSV(statistics)
    }

    // MARK: - Configuration Management

    /// Update configuration for a specific validator
    /// - Parameters:
    ///   - name: Name of the validator
    ///   - config: New configuration parameters
    public func updateValidatorConfiguration(
        _ name: String,
        config: [String: Any]
    ) throws {
        if var validator = getValidator(named: name) {
            try validator.updateConfiguration(config)
            logger.info("Updated configuration for validator '\(name)'")
        } else {
            throw ValidationError.validatorNotFound(name)
        }
    }

    /// Get configuration for all validators
    /// - Returns: Dictionary mapping validator names to their configurations
    public func getAllValidatorConfigurations() -> [String: [String: Any]] {
        var configurations: [String: [String: Any]] = [:]

        for validator in validators {
            configurations[validator.name] = validator.getConfiguration()
        }

        return configurations
    }

    // MARK: - Status and Reporting

    /// Get overall validation status
    /// - Returns: True if all validators passed, false otherwise
    public var overallValidationStatus: Bool {
        return lastValidationResults.values.allSatisfy { $0.isValid }
    }

    /// Get summary of validation results
    /// - Returns: Summary string with validation status and statistics
    public func getValidationSummary() -> String {
        let totalValidators = lastValidationResults.count
        let passedValidators = lastValidationResults.values.filter {
            $0.isValid
        }.count
        let totalArtifacts = lastStatisticsArtifacts.count

        return """
            Validation Summary:
            - Total Validators: \(totalValidators)
            - Passed: \(passedValidators)
            - Failed: \(totalValidators - passedValidators)
            - Statistics Artifacts: \(totalArtifacts)
            - Overall Status: \(overallValidationStatus ? "PASS" : "FAIL")
            """
    }

    /// Clear all validation results and artifacts
    public func clearResults() {
        lastValidationResults.removeAll()
        lastStatisticsArtifacts.removeAll()
        logger.info("Cleared all validation results and artifacts")
    }
}

// MARK: - Supporting Types

/// Summary information about a validator
public struct ValidatorSummary: Sendable {
    public let name: String
    public let description: String
    public let isEnabled: Bool
    public let priority: Int
    public let lastResult: DataValidationResult?

    public var status: String {
        if lastResult == nil {
            return "Not Run"
        }
        return lastResult!.isValid ? "Passed" : "Failed"
    }

    public var errorCount: Int {
        return lastResult?.errors.count ?? 0
    }

    public var warningCount: Int {
        return lastResult?.warnings.count ?? 0
    }
}

/// Configuration for a validator
public struct ValidatorConfiguration: Codable, Sendable {
    public let name: String
    public let isEnabled: Bool
    public let priority: Int
    public let configuration: [String: String]  // String-based config for JSON compatibility
}

/// Overall plugin configuration
public struct PluginConfiguration: Codable, Sendable {
    public let pluginsEnabled: Bool
    public let validators: [ValidatorConfiguration]
}

// MARK: - Built-in Validators

/// Validator that checks for missing gate_anom values
public struct NoMissingGateAnomValidator: PipelineValidator {
    public let name = "NoMissingGateAnom"
    public let description =
        "Ensures no probe ticks are missing gate_anom values"
    public var isEnabled: Bool = true
    public let priority: Int = 100

    public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
        let total = ticks.count
        let missing = ticks.filter { $0.gate_anom == nil }

        if !missing.isEmpty {
            return DataValidationResult(
                totalRecords: total,
                isValid: false,
                errors: ["Missing gate_anom in \(missing.count) records"],
                warnings: []
            )
        } else {
            return DataValidationResult(
                totalRecords: total,
                isValid: true,
                errors: [],
                warnings: []
            )
        }
    }

    public func validate(features: [FeatureVector]) -> DataValidationResult {
        // Not applicable for features
        return DataValidationResult(
            totalRecords: features.count,
            isValid: true,
            errors: [],
            warnings: [
                "Gate anomaly validation not applicable to feature vectors"
            ]
        )
    }

    public func validate(metrics _: ModelPerformanceMetrics)
        -> DataValidationResult
    {
        // Not applicable for model metrics
        return DataValidationResult(
            totalRecords: 1,
            isValid: true,
            errors: [],
            warnings: [
                "Gate anomaly validation not applicable to model metrics"
            ]
        )
    }

    public func getConfiguration() -> [String: Any] {
        return [:]
    }

    public mutating func updateConfiguration(_: [String: Any]) throws {
        // No configurable parameters
    }

    public func generateStatistics(from _: [ProbeTickRaw])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }

    public func generateStatistics(from _: [FeatureVector])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }
}

/// Validator that checks for reasonable detour_delta values
public class DetourDeltaRangeValidator: PipelineValidator {
    public let name = "DetourDeltaRange"
    public let description =
        "Ensures detour_delta values are within reasonable bounds"
    public var isEnabled: Bool = true
    public let priority: Int = 200

    // Configurable thresholds
    private var minDetourDelta: Double = -100.0
    private var maxDetourDelta: Double = 100.0

    public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
        let total = ticks.count

        let outOfRange = ticks.filter { tick in
            if tick.detour_delta == nil { return false }
            let detourDelta = tick.detour_delta!
            return detourDelta < minDetourDelta || detourDelta > maxDetourDelta
        }

        if !outOfRange.isEmpty {
            return DataValidationResult(
                totalRecords: total,
                isValid: false,
                errors: [
                    "\(outOfRange.count) records have detour_delta outside valid range [\(minDetourDelta), \(maxDetourDelta)]"
                ],
                warnings: []
            )
        } else {
            return DataValidationResult(
                totalRecords: total,
                isValid: true,
                errors: [],
                warnings: []
            )
        }
    }

    public func validate(features: [FeatureVector]) -> DataValidationResult {
        // Not applicable for features
        return DataValidationResult(
            totalRecords: features.count,
            isValid: true,
            errors: [],
            warnings: [
                "Detour delta validation not applicable to feature vectors"
            ]
        )
    }

    public func validate(metrics _: ModelPerformanceMetrics)
        -> DataValidationResult
    {
        // Not applicable for model metrics
        return DataValidationResult(
            totalRecords: 1,
            isValid: true,
            errors: [],
            warnings: [
                "Detour delta validation not applicable to model metrics"
            ]
        )
    }

    public func getConfiguration() -> [String: Any] {
        return [
            "minDetourDelta": minDetourDelta,
            "maxDetourDelta": maxDetourDelta,
        ]
    }

    public func updateConfiguration(_ config: [String: Any]) throws {
        if let min = config["minDetourDelta"] as? Double {
            minDetourDelta = min
        }
        if let max = config["maxDetourDelta"] as? Double {
            maxDetourDelta = max
        }

        // Validate configuration
        if minDetourDelta >= maxDetourDelta {
            throw ValidationError.invalidConfiguration(
                "minDetourDelta must be less than maxDetourDelta"
            )
        }
    }

    public func generateStatistics(from _: [ProbeTickRaw])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }

    public func generateStatistics(from _: [FeatureVector])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }
}

/// Validator that checks data quality metrics
public struct DataQualityValidator: PipelineValidator {
    public let name = "DataQuality"
    public let description = "Ensures data quality meets minimum thresholds"
    public var isEnabled: Bool = true
    public let priority: Int = 300

    // Configurable thresholds
    private var minValidationRate: Double = 0.95
    private var maxErrorRate: Double = 0.05

    public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
        let total = ticks.count

        // Count various data quality issues
        var errorCount = 0
        var warnings: [String] = []
        var errors: [String] = []

        // Check for null values in critical fields
        let nullGateAnom = ticks.filter { $0.gate_anom == nil }.count
        let nullDetourDelta = ticks.filter { $0.detour_delta == nil }.count

        // Count empty ts_utc strings (no need to check nil as ts_utc is non-optional)
        let nullTsUTC = ticks.filter { $0.ts_utc == "" }.count

        if nullGateAnom > 0 {
            warnings.append("\(nullGateAnom) records have null gate_anom")
        }
        if nullDetourDelta > 0 {
            warnings.append("\(nullDetourDelta) records have null detour_delta")
        }
        if nullTsUTC > 0 {
            errorCount += nullTsUTC
            errors.append("\(nullTsUTC) records have null or empty ts_utc")
        }

        // Check for extreme values
        let extremeDetourDelta = ticks.compactMap { $0.detour_delta }.filter {
            abs($0) > 1000
        }.count
        if extremeDetourDelta > 0 {
            warnings.append(
                "\(extremeDetourDelta) records have extreme detour_delta values (>1000)"
            )
        }

        errors.append(contentsOf: warnings)

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: warnings
        )
    }

    public func validate(features: [FeatureVector]) -> DataValidationResult {
        let total = features.count

        var errorCount = 0
        var errors: [String] = []

        for (index, feature) in features.enumerated() {
            // Check cyclical features are in valid range
            if feature.min_sin < -1.0 || feature.min_sin > 1.0
                || feature.min_cos < -1.0
                || feature.min_cos > 1.0 || feature.dow_sin < -1.0
                || feature.dow_sin > 1.0
                || feature.dow_cos < -1.0 || feature.dow_cos > 1.0
            {
                errorCount += 1
                if errorCount <= 5 {  // Limit error messages
                    errors.append(
                        "Feature \(index) has invalid cyclical values"
                    )
                }
            }
        }

        if errorCount > 5 {
            errors.append(
                "... and \(errorCount - 5) more features with invalid cyclical values"
            )
        }

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: []
        )
    }

    public func validate(metrics: ModelPerformanceMetrics)
        -> DataValidationResult
    {
        let total = 1

        var errorCount = 0
        var warnings: [String] = []
        var errors: [String] = []

        // Check performance thresholds
        if metrics.accuracy < 0.7 {
            errorCount += 1
            errors.append(
                "Model accuracy \(String(format: "%.3f", metrics.accuracy)) below threshold 0.7"
            )
        } else if metrics.accuracy < 0.8 {
            warnings.append(
                "Model accuracy \(String(format: "%.3f", metrics.accuracy)) is acceptable but could be improved"
            )
        }

        if metrics.loss > 0.5 {
            errorCount += 1
            errors.append(
                "Model loss \(String(format: "%.3f", metrics.loss)) above threshold 0.5"
            )
        }

        if metrics.f1Score < 0.65 {
            errorCount += 1
            errors.append(
                "Model F1 score \(String(format: "%.3f", metrics.f1Score)) below threshold 0.65"
            )
        }

        errors.append(contentsOf: warnings)

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: warnings
        )
    }

    public func getConfiguration() -> [String: Any] {
        return [
            "minValidationRate": minValidationRate,
            "maxErrorRate": maxErrorRate,
        ]
    }

    public mutating func updateConfiguration(_ config: [String: Any]) throws {
        if let min = config["minValidationRate"] as? Double {
            minValidationRate = min
        }
        if let max = config["maxErrorRate"] as? Double {
            maxErrorRate = max
        }

        // Validate configuration
        if minValidationRate < 0.0 || minValidationRate > 1.0 {
            throw ValidationError.invalidConfiguration(
                "minValidationRate must be between 0.0 and 1.0"
            )
        }
        if maxErrorRate < 0.0 || maxErrorRate > 1.0 {
            throw ValidationError.invalidConfiguration(
                "maxErrorRate must be between 0.0 and 1.0"
            )
        }
        if minValidationRate + maxErrorRate > 1.0 {
            throw ValidationError.invalidConfiguration(
                "minValidationRate + maxErrorRate cannot exceed 1.0"
            )
        }
    }

    public func generateStatistics(from _: [ProbeTickRaw])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }

    public func generateStatistics(from _: [FeatureVector])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }
}

/// Validator that checks speed field ranges
public struct SpeedRangeValidator: PipelineValidator {
    public let name = "SpeedRange"
    public let description = "Ensures speed values are within reasonable bounds"
    public var isEnabled: Bool = true
    public let priority: Int = 400

    // Configurable thresholds
    private var minSpeed: Double = 0.0
    private var maxSpeed: Double = 100.0  // mph

    // Statistics service for generating comprehensive artifacts
    private let statisticsService = DataStatisticsService()

    public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
        let total = ticks.count

        var errorCount = 0
        var errors: [String] = []
        var warnings: [String] = []

        // Validate current traffic speed
        let currentSpeedViolations = ticks.compactMap {
            tick -> (ProbeTickRaw, String)? in
            guard let speed = tick.current_traffic_speed else { return nil }
            if speed < minSpeed || speed > maxSpeed {
                return (
                    tick,
                    "Current traffic speed \(speed) mph outside valid range [\(minSpeed), \(maxSpeed)]"
                )
            }
            return nil
        }

        // Validate normal traffic speed
        let normalSpeedViolations = ticks.compactMap {
            tick -> (ProbeTickRaw, String)? in
            guard let speed = tick.normal_traffic_speed else { return nil }
            if speed < minSpeed || speed > maxSpeed {
                return (
                    tick,
                    "Normal traffic speed \(speed) mph outside valid range [\(minSpeed), \(maxSpeed)]"
                )
            }
            return nil
        }

        // Check for speed ratio anomalies
        let speedRatioViolations = ticks.compactMap {
            tick -> (ProbeTickRaw, String)? in
            guard let current = tick.current_traffic_speed,
                let normal = tick.normal_traffic_speed,
                normal > 0
            else { return nil }

            let ratio = current / normal
            if ratio < 0.1 || ratio > 3.0 {  // Speed ratio should be reasonable
                return (
                    tick,
                    "Speed ratio \(String(format: "%.2f", ratio)) outside reasonable bounds [0.1, 3.0]"
                )
            }
            return nil
        }

        // Count total violations
        let totalViolations =
            currentSpeedViolations.count + normalSpeedViolations.count
            + speedRatioViolations.count
        errorCount += totalViolations

        // Build error messages
        if !currentSpeedViolations.isEmpty {
            errors.append(
                "\(currentSpeedViolations.count) records have current traffic speed outside valid range [\(minSpeed), \(maxSpeed)] mph"
            )
        }

        if !normalSpeedViolations.isEmpty {
            errors.append(
                "\(normalSpeedViolations.count) records have normal traffic speed outside valid range [\(minSpeed), \(maxSpeed)] mph"
            )
        }

        if !speedRatioViolations.isEmpty {
            errors.append(
                "\(speedRatioViolations.count) records have unreasonable speed ratios"
            )
        }

        // Add warnings for missing speed data
        let ticksWithSpeedData = ticks.filter {
            $0.current_traffic_speed != nil || $0.normal_traffic_speed != nil
        }
        if ticksWithSpeedData.count < Int(Double(total) * 0.5) {
            warnings.append(
                "Only \(String(format: "%.1f%%", Double(ticksWithSpeedData.count) / Double(total) * 100)) of records contain speed data"
            )
        }

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: warnings
        )
    }

    public func validate(features: [FeatureVector]) -> DataValidationResult {
        let total = features.count

        var errorCount = 0
        var errors: [String] = []
        var warnings: [String] = []

        // Validate current speed features
        let currentSpeedViolations = features.filter { feature in
            feature.current_speed < minSpeed || feature.current_speed > maxSpeed
        }

        // Validate normal speed features
        let normalSpeedViolations = features.filter { feature in
            feature.normal_speed < minSpeed || feature.normal_speed > maxSpeed
        }

        // Check for speed ratio anomalies
        let speedRatioViolations = features.filter { feature in
            let ratio = feature.current_speed / feature.normal_speed
            return ratio < 0.1 || ratio > 3.0
        }

        // Count total violations
        let totalViolations =
            currentSpeedViolations.count + normalSpeedViolations.count
            + speedRatioViolations.count
        errorCount += totalViolations

        // Build error messages
        if !currentSpeedViolations.isEmpty {
            errors.append(
                "\(currentSpeedViolations.count) features have current speed outside valid range [\(minSpeed), \(maxSpeed)] mph"
            )
        }

        if !normalSpeedViolations.isEmpty {
            errors.append(
                "\(normalSpeedViolations.count) features have normal speed outside valid range [\(minSpeed), \(maxSpeed)] mph"
            )
        }

        if !speedRatioViolations.isEmpty {
            errors.append(
                "\(speedRatioViolations.count) features have unreasonable speed ratios"
            )
        }

        // Add warnings for extreme speed values
        let extremeSpeeds = features.filter {
            $0.current_speed > 80 || $0.normal_speed > 80
        }
        if !extremeSpeeds.isEmpty {
            warnings.append(
                "\(extremeSpeeds.count) features have speeds above 80 mph (highway speeds)"
            )
        }

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: warnings
        )
    }

    public func validate(metrics _: ModelPerformanceMetrics)
        -> DataValidationResult
    {
        // Not applicable for model metrics
        return DataValidationResult(
            totalRecords: 1,
            isValid: true,
            errors: [],
            warnings: ["Speed validation not applicable to model metrics"]
        )
    }

    public func getConfiguration() -> [String: Any] {
        return [
            "minSpeed": minSpeed,
            "maxSpeed": maxSpeed,
        ]
    }

    public mutating func updateConfiguration(_ config: [String: Any]) throws {
        if let min = config["minSpeed"] as? Double {
            minSpeed = min
        }
        if let max = config["maxSpeed"] as? Double {
            maxSpeed = max
        }

        // Validate configuration
        if minSpeed < 0.0 {
            throw ValidationError.invalidConfiguration(
                "minSpeed cannot be negative"
            )
        }
        if maxSpeed <= minSpeed {
            throw ValidationError.invalidConfiguration(
                "maxSpeed must be greater than minSpeed"
            )
        }
    }

    public func generateStatistics(from _: [ProbeTickRaw])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }

    public func generateStatistics(from _: [FeatureVector])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }
}

/// Validator that checks timestamp monotonicity
public struct TimestampMonotonicityValidator: PipelineValidator {
    public let name = "TimestampMonotonicity"
    public let description =
        "Ensures timestamps increase monotonically without backward jumps"
    public var isEnabled: Bool = true
    public let priority: Int = 500

    // Configurable thresholds
    private var maxBackwardJumpSeconds: Double = 300.0  // 5 minutes
    private var maxForwardJumpSeconds: Double = 3600.0  // 1 hour

    public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
        let total = ticks.count

        var errorCount = 0
        var warnings: [String] = []
        var errors: [String] = []

        // Sort ticks by timestamp for monotonicity check
        let sortedTicks = ticks.sorted { tick1, tick2 in
            guard let ts1 = ISO8601DateFormatter().date(from: tick1.ts_utc),
                let ts2 = ISO8601DateFormatter().date(from: tick2.ts_utc)
            else {
                return false
            }
            return ts1 < ts2
        }

        var previousTimestamp: Date?
        var backwardJumps = 0
        var forwardJumps = 0

        for tick in sortedTicks {
            guard
                let currentTimestamp = ISO8601DateFormatter().date(
                    from: tick.ts_utc
                )
            else {
                errorCount += 1
                if errorCount <= 5 {
                    errors.append("Invalid timestamp format: \(tick.ts_utc)")
                }
                continue
            }

            if let previous = previousTimestamp {
                let timeDifference = currentTimestamp.timeIntervalSince(
                    previous
                )

                if timeDifference < -maxBackwardJumpSeconds {
                    backwardJumps += 1
                    if backwardJumps <= 3 {
                        errors.append(
                            "Backward timestamp jump detected: \(timeDifference)s from \(previous) to \(currentTimestamp)"
                        )
                    }
                } else if timeDifference > maxForwardJumpSeconds {
                    forwardJumps += 1
                    if forwardJumps <= 3 {
                        warnings.append(
                            "Large forward timestamp jump detected: \(timeDifference)s from \(previous) to \(currentTimestamp)"
                        )
                    }
                }
            }

            previousTimestamp = currentTimestamp
        }

        if backwardJumps > 3 {
            errors.append(
                "... and \(backwardJumps - 3) more backward timestamp jumps"
            )
        }
        if forwardJumps > 3 {
            warnings.append(
                "... and \(forwardJumps - 3) more forward timestamp jumps"
            )
        }

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: warnings
        )
    }

    public func validate(features: [FeatureVector]) -> DataValidationResult {
        // Not applicable for features (they don't have timestamps)
        return DataValidationResult(
            totalRecords: features.count,
            isValid: true,
            errors: [],
            warnings: [
                "Timestamp monotonicity validation not applicable to feature vectors"
            ]
        )
    }

    public func validate(metrics _: ModelPerformanceMetrics)
        -> DataValidationResult
    {
        // Not applicable for model metrics
        return DataValidationResult(
            totalRecords: 1,
            isValid: true,
            errors: [],
            warnings: [
                "Timestamp monotonicity validation not applicable to model metrics"
            ]
        )
    }

    public func getConfiguration() -> [String: Any] {
        return [
            "maxBackwardJumpSeconds": maxBackwardJumpSeconds,
            "maxForwardJumpSeconds": maxForwardJumpSeconds,
        ]
    }

    public mutating func updateConfiguration(_ config: [String: Any]) throws {
        if let backward = config["maxBackwardJumpSeconds"] as? Double {
            maxBackwardJumpSeconds = backward
        }
        if let forward = config["maxForwardJumpSeconds"] as? Double {
            maxForwardJumpSeconds = forward
        }

        // Validate configuration
        if maxBackwardJumpSeconds < 0.0 {
            throw ValidationError.invalidConfiguration(
                "maxBackwardJumpSeconds cannot be negative"
            )
        }
        if maxForwardJumpSeconds < 0.0 {
            throw ValidationError.invalidConfiguration(
                "maxForwardJumpSeconds cannot be negative"
            )
        }
    }

    // MARK: - Helper Methods

    /// Dynamically detects available horizons from probe tick data
    private func detectAvailableHorizons(from _: [ProbeTickRaw]) -> [Int] {
        // This is a placeholder - in practice, you'd extract horizon information
        // from the tick data based on your actual data structure
        // For now, return a reasonable default set
        return [0, 3, 6, 9, 12]
    }

    /// Detects gaps in horizon sequence
    private func detectHorizonGaps(in horizons: [Int]) -> [Int] {
        guard horizons.count > 1 else { return [] }

        var gaps: [Int] = []
        let sorted = horizons.sorted()

        for i in 0..<(sorted.count - 1) {
            let current = sorted[i]
            let next = sorted[i + 1]
            let expectedNext = current + 3  // Assuming 3-minute intervals

            if next != expectedNext {
                for missing in stride(from: expectedNext, to: next, by: 3) {
                    gaps.append(missing)
                }
            }
        }

        return gaps
    }

    public func generateStatistics(from _: [ProbeTickRaw])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }

    public func generateStatistics(from _: [FeatureVector])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }
}

/// Validator that checks horizon coverage for features (and N/A for raw ticks)
public struct HorizonCoverageValidator: PipelineValidator {
    public let name = "HorizonCoverage"
    public let description =
        "Ensures expected prediction horizons are present and reasonably balanced"
    public var isEnabled: Bool = true
    public let priority: Int = 600

    // Configurable parameters
    private var expectedHorizons: [Int] = defaultHorizons
    private var requireAllHorizons: Bool = true
    private var maxImbalanceRatio: Double = 2.0
    private var minPerHorizonCount: Int = 1

    public init() {}

    public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
        // Horizons are not explicit in raw ticks; treat as not applicable
        return DataValidationResult(
            totalRecords: ticks.count,
            isValid: true,
            errors: [],
            warnings: [
                "Horizon coverage validation not applicable to raw ticks"
            ]
        )
    }

    public func validate(features: [FeatureVector]) -> DataValidationResult {
        var result = DataValidationResult(
            totalRecords: features.count,
            isValid: true,
            errors: [],
            warnings: []
        )

        guard !features.isEmpty else {
            result.isValid = false
            result.errors.append("No feature vectors provided")
            return result
        }

        // Count coverage per horizon
        var coverage: [Int: Int] = [:]
        for f in features {
            coverage[f.horizon_min, default: 0] += 1
        }
        result.horizonCoverage = coverage

        // Check for missing horizons
        let expected = Set(expectedHorizons)
        let actual = Set(coverage.keys)
        let missing = expected.subtracting(actual).sorted()

        if requireAllHorizons && !missing.isEmpty {
            result.isValid = false
            result.errors.append(
                "Missing features for horizons: \(missing.map { "\($0)min" }.joined(separator: ", "))"
            )
        } else if !missing.isEmpty {
            result.warnings.append(
                "Missing features for horizons: \(missing.map { "\($0)min" }.joined(separator: ", "))"
            )
        }

        // Check minimum count per horizon
        let lowCountHorizons = coverage.filter { $0.value < minPerHorizonCount }
            .map { $0.key }.sorted()
        if !lowCountHorizons.isEmpty {
            result.warnings.append(
                "Low sample count for horizons: \(lowCountHorizons.map { "\($0)min" }.joined(separator: ", ")) (<\(minPerHorizonCount) samples)"
            )
        }

        // Check imbalance ratio across horizons
        let counts = coverage.values
        if let minCount = counts.min(), let maxCount = counts.max(),
            minCount > 0
        {
            let ratio = Double(maxCount) / Double(minCount)
            if ratio > maxImbalanceRatio {
                result.warnings.append(
                    "Unbalanced horizon distribution: ratio \(String(format: "%.1f", ratio)) (> \(String(format: "%.1f", maxImbalanceRatio)))"
                )
            }
        }

        return result
    }

    public func validate(metrics _: ModelPerformanceMetrics)
        -> DataValidationResult
    {
        // Not applicable for model metrics
        return DataValidationResult(
            totalRecords: 1,
            isValid: true,
            errors: [],
            warnings: [
                "Horizon coverage validation not applicable to model metrics"
            ]
        )
    }

    public func getConfiguration() -> [String: Any] {
        return [
            "expectedHorizons": expectedHorizons,
            "requireAllHorizons": requireAllHorizons,
            "maxImbalanceRatio": maxImbalanceRatio,
            "minPerHorizonCount": minPerHorizonCount,
        ]
    }

    public mutating func updateConfiguration(_ config: [String: Any]) throws {
        if let horizons = config["expectedHorizons"] as? [Int] {
            expectedHorizons = horizons
        }
        if let requireAll = config["requireAllHorizons"] as? Bool {
            requireAllHorizons = requireAll
        }
        if let ratio = config["maxImbalanceRatio"] as? Double {
            guard ratio >= 1.0 else {
                throw ValidationError.invalidConfiguration(
                    "maxImbalanceRatio must be >= 1.0"
                )
            }
            maxImbalanceRatio = ratio
        }
        if let minCount = config["minPerHorizonCount"] as? Int {
            guard minCount >= 0 else {
                throw ValidationError.invalidConfiguration(
                    "minPerHorizonCount must be >= 0"
                )
            }
            minPerHorizonCount = minCount
        }
    }

    public func generateStatistics(from _: [ProbeTickRaw])
        -> BridgeDataStatistics?
    {
        // No statistics generation for raw ticks
        return nil
    }

    public func generateStatistics(from _: [FeatureVector])
        -> BridgeDataStatistics?
    {
        // Could emit coverage histograms in future
        return nil
    }
}

/// Validator that explicitly checks for NaN and infinite values
public struct NaNInfValidator: PipelineValidator {
    public let name = "NaNInf"
    public let description =
        "Explicitly checks for NaN and infinite values in numeric fields"
    public var isEnabled: Bool = true
    public let priority: Int = 700

    public func validate(ticks: [ProbeTickRaw]) -> DataValidationResult {
        let total = ticks.count

        var errorCount = 0
        var errors: [String] = []

        // Check for NaN/Inf in numeric fields
        for (index, tick) in ticks.enumerated() {
            if let detourDelta = tick.detour_delta {
                if detourDelta.isNaN {
                    errorCount += 1
                    if errorCount <= 5 {
                        errors.append("Record \(index) has NaN detour_delta")
                    }
                } else if detourDelta.isInfinite {
                    errorCount += 1
                    if errorCount <= 5 {
                        errors.append(
                            "Record \(index) has infinite detour_delta"
                        )
                    }
                }
            }

            // Add checks for other numeric fields when available
        }

        if errorCount > 5 {
            errors.append(
                "... and \(errorCount - 5) more records with NaN/Inf values"
            )
        }

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: []
        )
    }

    public func validate(features: [FeatureVector]) -> DataValidationResult {
        let total = features.count

        var errorCount = 0
        var errors: [String] = []

        // Check for NaN/Inf in feature values
        for (index, feature) in features.enumerated() {
            // Check cyclical features
            if feature.min_sin.isNaN || feature.min_sin.isInfinite
                || feature.min_cos.isNaN
                || feature.min_cos.isInfinite || feature.dow_sin.isNaN
                || feature.dow_sin.isInfinite
                || feature.dow_cos.isNaN || feature.dow_cos.isInfinite
            {
                errorCount += 1
                if errorCount <= 5 {
                    errors.append(
                        "Feature \(index) has NaN/Inf cyclical values"
                    )
                }
            }

            // Add checks for other numeric features when available
        }

        if errorCount > 5 {
            errors.append(
                "... and \(errorCount - 5) more features with NaN/Inf values"
            )
        }

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: []
        )
    }

    public func validate(metrics: ModelPerformanceMetrics)
        -> DataValidationResult
    {
        let total = 1

        var errorCount = 0
        var errors: [String] = []

        // Check for NaN/Inf in metrics
        if metrics.accuracy.isNaN || metrics.accuracy.isInfinite {
            errorCount += 1
            errors.append("Model accuracy is NaN or infinite")
        }
        if metrics.loss.isNaN || metrics.loss.isInfinite {
            errorCount += 1
            errors.append("Model loss is NaN or infinite")
        }
        if metrics.f1Score.isNaN || metrics.f1Score.isInfinite {
            errorCount += 1
            errors.append("Model F1 score is NaN or infinite")
        }

        let isValid = errorCount == 0

        return DataValidationResult(
            totalRecords: total,
            isValid: isValid,
            errors: errors,
            warnings: []
        )
    }

    public func getConfiguration() -> [String: Any] {
        return [:]
    }

    public mutating func updateConfiguration(_: [String: Any]) throws {
        // No configurable parameters
    }

    public func generateStatistics(from _: [ProbeTickRaw])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }

    public func generateStatistics(from _: [FeatureVector])
        -> BridgeDataStatistics?
    {
        // No statistics generation for this validator
        return nil
    }
}

// MARK: - Error Types

public enum ValidationError: Error, LocalizedError {
    case invalidConfiguration(String)
    case validatorNotFound(String)

    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let message):
            return "Invalid configuration: \(message)"
        case .validatorNotFound(let name):
            return "Validator with name '\(name)' not found."
        }
    }
}
