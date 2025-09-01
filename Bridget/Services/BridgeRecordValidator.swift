// BridgeRecordValidator.swift
// Encapsulates all bridge record validation logic, using ValidationUtils
//
// Created for Bridget app to reduce duplication and centralize business logic

import Foundation

struct BridgeRecordValidator {
    let knownBridgeIDs: Set<String>
    let bridgeLocations: [String: (lat: Double, lon: Double)]

    let minDate: Date
    let maxDate: Date
    let validEntityTypes: Set<String>

    private let coordinateTransformService: DefaultCoordinateTransformService

    // Phase 3.1: Configuration for transformation-based validation
    private let tightThresholdMeters: Double = 500.0  // 500m tight threshold
    private let fallbackThresholdMeters: Double = 8000.0  // 8km fallback threshold
    private let enableTransformationBasedValidation: Bool = true

    init(
        knownBridgeIDs: Set<String>,
        bridgeLocations: [String: (lat: Double, lon: Double)],
        validEntityTypes: Set<String>,
        minDate: Date,
        maxDate: Date,
        coordinateTransformService: DefaultCoordinateTransformService =
            DefaultCoordinateTransformService()
    ) {
        self.knownBridgeIDs = knownBridgeIDs
        self.bridgeLocations = bridgeLocations
        self.validEntityTypes = validEntityTypes
        self.minDate = minDate
        self.maxDate = maxDate
        self.coordinateTransformService = coordinateTransformService
    }

    /// Returns first validation failure reason, or nil if valid, using ValidationUtils
    func validationFailure(for record: BridgeOpeningRecord)
        -> ValidationFailureReason?
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
        guard let lat = record.latitudeValue, isInRange(lat, -90.0...90.0)
        else {
            return .invalidLatitude(record.latitudeValue)
        }
        guard let lon = record.longitudeValue, isInRange(lon, -180.0...180.0)
        else {
            return .invalidLongitude(record.longitudeValue)
        }
        guard let minutesOpen = record.minutesOpenValue, minutesOpen >= 0 else {
            return .negativeMinutesOpen(record.minutesOpenValue)
        }
        let actualMinutes = Int(closeDate.timeIntervalSince(openDate) / 60)
        if abs(minutesOpen - actualMinutes) > 1 {
            return .minutesOpenMismatch(
                reported: minutesOpen,
                actual: actualMinutes
            )
        }

        // Phase 3.1: Enhanced geospatial validation with transformation-based approach
        if let expected = bridgeLocations[record.entityid] {
            return validateGeospatialWithTransformation(
                record: record,
                inputLat: lat,
                inputLon: lon,
                expectedLat: expected.lat,
                expectedLon: expected.lon
            )
        }

        return nil
    }

    // MARK: - Private helpers

    /// Haversine distance between two lat/lon points in meters
    private func haversineDistanceMeters(
        lat1: Double,
        lon1: Double,
        lat2: Double,
        lon2: Double
    ) -> Double {
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

    /// Phase 3.1: Enhanced geospatial validation using transformation-based approach
    private func validateGeospatialWithTransformation(
        record: BridgeOpeningRecord,
        inputLat: Double,
        inputLon: Double,
        expectedLat: Double,
        expectedLon: Double
    ) -> ValidationFailureReason? {

        guard enableTransformationBasedValidation else {
            // Fallback to original threshold-based validation
            return validateGeospatialWithThreshold(
                record: record,
                inputLat: inputLat,
                inputLon: inputLon,
                expectedLat: expectedLat,
                expectedLon: expectedLon
            )
        }

        // Step 1: Apply coordinate transformation
        let transformationResult =
            coordinateTransformService.transformToReferenceSystem(
                latitude: inputLat,
                longitude: inputLon,
                from: .seattleAPI,
                bridgeId: record.entityid
            )

        let transformedLat: Double
        let transformedLon: Double
        let transformationSuccessful: Bool

        if transformationResult.success {
            transformedLat =
                transformationResult.transformedLatitude ?? inputLat
            transformedLon =
                transformationResult.transformedLongitude ?? inputLon
            transformationSuccessful = true
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
        }

        // Step 2: Calculate distance using Haversine formula
        let distanceMeters = haversineDistanceMeters(
            lat1: expectedLat,
            lon1: expectedLon,
            lat2: transformedLat,
            lon2: transformedLon
        )

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
            return nil
        }

        // Step 4: Fallback to 8km threshold if transformation was successful but distance is too far
        if transformationSuccessful && distanceMeters <= fallbackThresholdMeters
        {
            print(
                "⚠️ Bridge \(record.entityid) passed fallback threshold: \(String(format: "%.1f", distanceMeters))m (tight threshold: \(tightThresholdMeters)m)"
            )
            return nil
        }

        // Step 5: If transformation failed, try original threshold-based validation as final fallback
        if !transformationSuccessful {
            return validateGeospatialWithThreshold(
                record: record,
                inputLat: inputLat,
                inputLon: inputLon,
                expectedLat: expectedLat,
                expectedLon: expectedLon
            )
        }

        // Step 6: All validation methods failed
        return .geospatialMismatch(
            expectedLat: expectedLat,
            expectedLon: expectedLon,
            actualLat: transformedLat,
            actualLon: transformedLon
        )
    }

    /// Original threshold-based validation as fallback
    private func validateGeospatialWithThreshold(
        record: BridgeOpeningRecord,
        inputLat: Double,
        inputLon: Double,
        expectedLat: Double,
        expectedLon: Double
    ) -> ValidationFailureReason? {

        let latDiff = abs(expectedLat - inputLat)
        let lonDiff = abs(expectedLon - inputLon)

        if latDiff > 0.01 || lonDiff > 0.01 {
            return .geospatialMismatch(
                expectedLat: expectedLat,
                expectedLon: expectedLon,
                actualLat: inputLat,
                actualLon: inputLon
            )
        } else if latDiff > 0.001 || lonDiff > 0.001 {
            // Log when coordinates are close but within tolerance (for debugging)
            print(
                "📍 Bridge \(record.entityid) coordinates close but accepted: expected (\(expectedLat), \(expectedLon)), got (\(inputLat), \(inputLon)) - diff: lat \(latDiff), lon \(lonDiff)"
            )
        }

        return nil
    }
}
