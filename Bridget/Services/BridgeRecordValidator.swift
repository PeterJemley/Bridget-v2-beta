// BridgeRecordValidator.swift
// Encapsulates all bridge record validation logic, using ValidationUtils
//
// Created for Bridget app to reduce duplication and centralize business logic

import Foundation

@MainActor
struct BridgeRecordValidator {
  let knownBridgeIDs: Set<String>
  let bridgeLocations: [String: (lat: Double, lon: Double)]

  let minDate: Date
  let maxDate: Date
  let validEntityTypes: Set<String>

  private let coordinateTransformService: DefaultCoordinateTransformService
  private let featureFlagService: DefaultFeatureFlagService
  private let metricsService: DefaultFeatureFlagMetricsService
  private let monitoringService:
    DefaultCoordinateTransformationMonitoringService

  // Phase 3.1: Configuration for transformation-based validation
  private let tightThresholdMeters: Double = 500.0  // 500m tight threshold
  private let fallbackThresholdMeters: Double = 8000.0  // 8km fallback threshold

  init(knownBridgeIDs: Set<String>,
       bridgeLocations: [String: (lat: Double, lon: Double)],
       validEntityTypes: Set<String>,
       minDate: Date,
       maxDate: Date,
       coordinateTransformService: DefaultCoordinateTransformService? = nil,
       featureFlagService: DefaultFeatureFlagService? = nil,
       metricsService: DefaultFeatureFlagMetricsService? = nil,
       monitoringService: DefaultCoordinateTransformationMonitoringService? =
         nil)
  {
    self.knownBridgeIDs = knownBridgeIDs
    self.bridgeLocations = bridgeLocations
    self.validEntityTypes = validEntityTypes
    self.minDate = minDate
    self.maxDate = maxDate
    self.coordinateTransformService = coordinateTransformService ?? DefaultCoordinateTransformService()
    // Resolve singletons inside the @MainActor-isolated initializer body
    self.featureFlagService =
      featureFlagService ?? DefaultFeatureFlagService.shared
    self.metricsService =
      metricsService ?? DefaultFeatureFlagMetricsService.shared
    self.monitoringService =
      monitoringService
        ?? DefaultCoordinateTransformationMonitoringService.shared
  }

  /// Returns first validation failure reason, or nil if valid, using ValidationUtils
  func validationFailure(for record: BridgeOpeningRecord)
    async -> ValidationFailureReason?
  {
    if !isNotEmpty(record.entityid) {
      return .emptyEntityID
    }
    if !isNotEmpty(record.entityname) {
      return .emptyEntityName
    }
    if !knownBridgeIDs.contains(record.entityid) {
      return .unknownBridgeID(record.entityid)
    }
    guard let openDate = record.openDate else {
      return .malformedOpenDate(record.opendatetime)
    }
    if openDate < minDate || openDate > maxDate {
      return .outOfRangeOpenDate(openDate)
    }
    guard let closeDate = record.closeDate else {
      return .malformedCloseDate(record.closedatetime)
    }
    if closeDate <= openDate {
      return .closeDateNotAfterOpenDate(open: openDate, close: closeDate)
    }
    guard let lat = record.latitudeValue, isInRange(lat, -90.0 ... 90.0)
    else {
      return .invalidLatitude(record.latitudeValue)
    }
    guard let lon = record.longitudeValue, isInRange(lon, -180.0 ... 180.0)
    else {
      return .invalidLongitude(record.longitudeValue)
    }
    guard let minutesOpen = record.minutesOpenValue, minutesOpen >= 0 else {
      return .negativeMinutesOpen(record.minutesOpenValue)
    }
    let actualMinutes = Int(closeDate.timeIntervalSince(openDate) / 60)
    if abs(minutesOpen - actualMinutes) > 1 {
      return .minutesOpenMismatch(reported: minutesOpen,
                                  actual: actualMinutes)
    }

    // Phase 3.1: Enhanced geospatial validation with transformation-based approach
    if let expected = bridgeLocations[record.entityid] {
      return await validateGeospatialWithTransformation(record: record,
                                                  inputLat: lat,
                                                  inputLon: lon,
                                                  expectedLat: expected.lat,
                                                  expectedLon: expected.lon)
    }

    return nil
  }

  // MARK: - Private helpers

  /// Haversine distance between two lat/lon points in meters
  private func haversineDistanceMeters(lat1: Double,
                                       lon1: Double,
                                       lat2: Double,
                                       lon2: Double) -> Double
  {
    let R = 6_371_000.0  // Earth radius in meters
    let φ1 = lat1 * .pi / 180
    let φ2 = lat2 * .pi / 180
    let Δφ = (lat2 - lat1) * .pi / 180
    let Δλ = (lon2 - lon1) * .pi / 180

    let a =
      sin(Δφ / 2) * sin(Δφ / 2)
        + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
    let c = 2 * atan2(sqrt(a), sqrt(1 - a))
    return R * c
  }

  /// Phase 4.1: Enhanced geospatial validation with feature flags and monitoring
  private func validateGeospatialWithTransformation(record: BridgeOpeningRecord,
                                                    inputLat: Double,
                                                    inputLon: Double,
                                                    expectedLat: Double,
                                                    expectedLon: Double) async -> ValidationFailureReason?
  {
    // Phase 4.1: Check feature flag for coordinate transformation
    let isTransformationEnabled = featureFlagService.isEnabled(.coordinateTransformation,
                                                               for: record.entityid)
    let abTestVariant = featureFlagService.getABTestVariant(.coordinateTransformation,
                                                            for: record.entityid)

    // Record feature flag decision
    metricsService.recordFeatureFlagDecision(flag: FeatureFlag.coordinateTransformation.rawValue,
                                             userId: record.entityid,
                                             enabled: isTransformationEnabled,
                                             variant: abTestVariant?.rawValue)

    guard isTransformationEnabled else {
      // Fallback to original threshold-based validation
      let startTime = CFAbsoluteTimeGetCurrent()
      let result = validateGeospatialWithThreshold(record: record,
                                                   inputLat: inputLat,
                                                   inputLon: inputLon,
                                                   expectedLat: expectedLat,
                                                   expectedLon: expectedLon)
      let processingTimeMs =
        (CFAbsoluteTimeGetCurrent() - startTime) * 1000

      // Record metrics for threshold-based validation
      metricsService.recordValidationResult(bridgeId: record.entityid,
                                            method: .threshold,
                                            success: result == nil,
                                            processingTimeMs: processingTimeMs,
                                            variant: abTestVariant?.rawValue)

      return result
    }

    // Step 1: Apply coordinate transformation with performance monitoring
    let startTime = CFAbsoluteTimeGetCurrent()
    let transformationResult = await
      coordinateTransformService.transformToReferenceSystem(latitude: inputLat,
                                                            longitude: inputLon,
                                                            from: .seattleAPI,
                                                            bridgeId: record.entityid)
    let processingTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000  // Performance metric

    let transformedLat: Double
    let transformedLon: Double
    let transformationSuccessful: Bool

    if transformationResult.success {
      transformedLat =
        transformationResult.transformedLatitude ?? inputLat
      transformedLon =
        transformationResult.transformedLongitude ?? inputLon
      transformationSuccessful = true

      // Record successful transformation monitoring event
      let distanceImprovement =
        haversineDistanceMeters(lat1: expectedLat,
                                lon1: expectedLon,
                                lat2: inputLat,
                                lon2: inputLon)
        - haversineDistanceMeters(lat1: expectedLat,
                                  lon1: expectedLon,
                                  lat2: transformedLat,
                                  lon2: transformedLon)

      monitoringService.recordSuccessfulTransformation(bridgeId: record.entityid,
                                                       sourceSystem: "SeattleAPI",
                                                       targetSystem: "SeattleReference",
                                                       confidence: transformationResult.confidence,
                                                       processingTimeMs: processingTimeMs,
                                                       distanceImprovementMeters: distanceImprovement,
                                                       userId: record.entityid)
    } else {
      // Log transformation failure for monitoring
      let errorMessage =
        transformationResult.error?.localizedDescription
          ?? "Unknown error"
      print(
        "⚠️ Coordinate transformation failed for bridge \(record.entityid): \(errorMessage)"
      )
      transformedLat = inputLat
      transformedLon = inputLon
      transformationSuccessful = false

      // Record failed transformation monitoring event
      monitoringService.recordFailedTransformation(bridgeId: record.entityid,
                                                   sourceSystem: "SeattleAPI",
                                                   targetSystem: "SeattleReference",
                                                   errorMessage: errorMessage,
                                                   processingTimeMs: processingTimeMs,
                                                   userId: record.entityid)
    }

    // Step 2: Calculate distance using Haversine formula
    let distanceMeters = haversineDistanceMeters(lat1: expectedLat,
                                                 lon1: expectedLon,
                                                 lat2: transformedLat,
                                                 lon2: transformedLon)

    // Step 3: Apply tight threshold (500m) for transformed coordinates
    if distanceMeters <= tightThresholdMeters {
      // Success with transformation-based validation
      if transformationSuccessful {
        print(
          "✅ Bridge \(record.entityid) validated with transformation: \(String(format: "%.1f", distanceMeters))m"
        )
      } else {
        print(
          "⚠️ Bridge \(record.entityid) validated with fallback: \(String(format: "%.1f", distanceMeters))m"
        )
      }

      // Record successful transformation validation
      metricsService.recordValidationResult(bridgeId: record.entityid,
                                            method: .transformation,
                                            success: true,
                                            processingTimeMs: processingTimeMs,
                                            distanceMeters: distanceMeters,
                                            variant: abTestVariant?.rawValue)

      return nil
    }

    // Step 4: Fallback to 8km threshold if transformation was successful but distance is too far
    if transformationSuccessful, distanceMeters <= fallbackThresholdMeters {
      print(
        "⚠️ Bridge \(record.entityid) passed fallback threshold: \(String(format: "%.1f", distanceMeters))m (tight threshold: \(tightThresholdMeters)m)"
      )

      // Record fallback validation success
      metricsService.recordValidationResult(bridgeId: record.entityid,
                                            method: .fallback,
                                            success: true,
                                            processingTimeMs: processingTimeMs,
                                            distanceMeters: distanceMeters,
                                            variant: abTestVariant?.rawValue)

      return nil
    }

    // Step 5: If transformation failed, try original threshold-based validation as final fallback
    if !transformationSuccessful {
      let result = validateGeospatialWithThreshold(record: record,
                                                   inputLat: inputLat,
                                                   inputLon: inputLon,
                                                   expectedLat: expectedLat,
                                                   expectedLon: expectedLon)

      // Record fallback validation result
      metricsService.recordValidationResult(bridgeId: record.entityid,
                                            method: .fallback,
                                            success: result == nil,
                                            processingTimeMs: processingTimeMs,
                                            variant: abTestVariant?.rawValue)

      return result
    }

    // Step 6: All validation methods failed
    // Record transformation validation failure
    metricsService.recordValidationResult(bridgeId: record.entityid,
                                          method: .transformation,
                                          success: false,
                                          processingTimeMs: processingTimeMs,
                                          distanceMeters: distanceMeters,
                                          variant: abTestVariant?.rawValue)

    return .geospatialMismatch(expectedLat: expectedLat,
                               expectedLon: expectedLon,
                               actualLat: transformedLat,
                               actualLon: transformedLon)
  }

  /// Original threshold-based validation as fallback
  private func validateGeospatialWithThreshold(record: BridgeOpeningRecord,
                                               inputLat: Double,
                                               inputLon: Double,
                                               expectedLat: Double,
                                               expectedLon: Double) -> ValidationFailureReason?
  {
    let latDiff = abs(expectedLat - inputLat)
    let lonDiff = abs(expectedLon - inputLon)

    if latDiff > 0.01 || lonDiff > 0.01 {
      return .geospatialMismatch(expectedLat: expectedLat,
                                 expectedLon: expectedLon,
                                 actualLat: inputLat,
                                 actualLon: inputLon)
    } else if latDiff > 0.001 || lonDiff > 0.001 {
      // Log when coordinates are close but within tolerance (for debugging)
      print(
        "📍 Bridge \(record.entityid) coordinates close but accepted: expected (\(expectedLat), \(expectedLon)), got (\(inputLat), \(inputLon)) - diff: lat \(latDiff), lon \(lonDiff)"
      )
    }

    return nil
  }
}
