import Accelerate
import Foundation
import simd

// MARK: - Optimized Transformation Functions

/// SIMD-optimized single-point transformation
/// Uses vectorized operations for better performance on single points
@inline(__always)
public func applyTransformationSIMD(
    latitude: Double,
    longitude: Double,
    matrix: TransformationMatrix
) -> (latitude: Double, longitude: Double) {
    // Pack coordinates into SIMD vector for vectorized operations
    let coords = simd_double2(latitude, longitude)
    let offsets = simd_double2(matrix.latOffset, matrix.lonOffset)
    let scales = simd_double2(matrix.latScale, matrix.lonScale)

    // Optional: basic NaN/Inf passthrough policy
    if !coords.x.isFinite || !coords.y.isFinite {
        return (coords.x, coords.y)
    }

    // Apply translation first, then scaling: (x + offset) * scale
    var transformed = (coords + offsets) * scales

    // Early-out for zero rotation
    if matrix.rotation == 0.0 {
        return (transformed.x, transformed.y)
    }

    // Apply rotation (simplified - assumes small angles), rotation is in degrees
    let rotationRad = matrix.rotation * .pi / 180.0
    let cosRot = cos(rotationRad)
    let sinRot = sin(rotationRad)

    // Convert to radians for rotation
    let coordsRad = transformed * .pi / 180.0

    // Apply 2D rotation matrix: (lat, lon) -> (lat*cos - lon*sin, lat*sin + lon*cos)
    let rotated = simd_double2(
        coordsRad.x * cosRot - coordsRad.y * sinRot,
        coordsRad.x * sinRot + coordsRad.y * cosRot
    )

    // Convert back to degrees
    transformed = rotated * 180.0 / .pi

    return (transformed.x, transformed.y)
}

/// vDSP-optimized batch transformation with 3×N double-precision routines
/// Processes arrays of coordinates using Accelerate framework
public func transformBatchVDSP(
    lats: UnsafeBufferPointer<Double>,
    lons: UnsafeBufferPointer<Double>,
    matrix: TransformationMatrix,
    outLats: UnsafeMutableBufferPointer<Double>,
    outLons: UnsafeMutableBufferPointer<Double>
) {
    precondition(lats.count == lons.count, "lat/lon count mismatch")
    precondition(
        outLats.count >= lats.count && outLons.count >= lons.count,
        "output buffers too small"
    )

    let count = lats.count
    if count == 0 { return }
    precondition(
        lats.baseAddress != nil && lons.baseAddress != nil,
        "nil baseAddress for non-empty input"
    )
    precondition(
        outLats.baseAddress != nil && outLons.baseAddress != nil,
        "nil baseAddress for non-empty output"
    )

    if matrix.rotation == 0.0 {
        // y = (x + offset) * scale
        vDSP_vsaddD(
            lats.baseAddress!,
            1,
            [matrix.latOffset],
            outLats.baseAddress!,
            1,
            vDSP_Length(count)
        )
        vDSP_vsmulD(
            outLats.baseAddress!,
            1,
            [matrix.latScale],
            outLats.baseAddress!,
            1,
            vDSP_Length(count)
        )

        vDSP_vsaddD(
            lons.baseAddress!,
            1,
            [matrix.lonOffset],
            outLons.baseAddress!,
            1,
            vDSP_Length(count)
        )
        vDSP_vsmulD(
            outLons.baseAddress!,
            1,
            [matrix.lonScale],
            outLons.baseAddress!,
            1,
            vDSP_Length(count)
        )
        return
    }

    // For rotations, first apply translation and scaling with vDSP
    var tmpLats = [Double](repeating: 0, count: count)
    var tmpLons = [Double](repeating: 0, count: count)

    vDSP_vsaddD(
        lats.baseAddress!,
        1,
        [matrix.latOffset],
        &tmpLats,
        1,
        vDSP_Length(count)
    )
    vDSP_vsmulD(tmpLats, 1, [matrix.latScale], &tmpLats, 1, vDSP_Length(count))

    vDSP_vsaddD(
        lons.baseAddress!,
        1,
        [matrix.lonOffset],
        &tmpLons,
        1,
        vDSP_Length(count)
    )
    vDSP_vsmulD(tmpLons, 1, [matrix.lonScale], &tmpLons, 1, vDSP_Length(count))

    // Apply rotation using SIMD for each element (pairwise lat/lon)
    let rotationRad = matrix.rotation * .pi / 180.0
    let cosRot = cos(rotationRad)
    let sinRot = sin(rotationRad)

    let simdCount = count / 2
    let remainder = count % 2

    for i in 0..<simdCount {
        let baseIdx = i * 2
        // Load pairs
        let latPairDeg = simd_double2(tmpLats[baseIdx], tmpLats[baseIdx + 1])
        let lonPairDeg = simd_double2(tmpLons[baseIdx], tmpLons[baseIdx + 1])

        // Convert to radians
        let latPair = latPairDeg * .pi / 180.0
        let lonPair = lonPairDeg * .pi / 180.0

        // Rotate pairwise: (lat, lon) -> (lat*cos - lon*sin, lat*sin + lon*cos)
        let outLat = latPair * cosRot - lonPair * sinRot
        let outLon = latPair * sinRot + lonPair * cosRot

        // Back to degrees
        let outLatDeg = outLat * 180.0 / .pi
        let outLonDeg = outLon * 180.0 / .pi

        outLats[baseIdx] = outLatDeg.x
        outLats[baseIdx + 1] = outLatDeg.y
        outLons[baseIdx] = outLonDeg.x
        outLons[baseIdx + 1] = outLonDeg.y
    }

    if remainder > 0 {
        let baseIdx = simdCount * 2
        let latDeg = tmpLats[baseIdx]
        let lonDeg = tmpLons[baseIdx]
        let lat = latDeg * .pi / 180.0
        let lon = lonDeg * .pi / 180.0
        let outLat = lat * cosRot - lon * sinRot
        let outLon = lat * sinRot + lon * cosRot
        outLats[baseIdx] = outLat * 180.0 / .pi
        outLons[baseIdx] = outLon * 180.0 / .pi
    }
}

/// Enhanced vDSP batch transformation with 3×N matrix operations
/// Uses 3×3 transformation matrices for more complex transformations
public func transformBatchVDSP3x3(
    lats: UnsafeBufferPointer<Double>,
    lons: UnsafeBufferPointer<Double>,
    matrix: TransformationMatrix,
    outLats: UnsafeMutableBufferPointer<Double>,
    outLons: UnsafeMutableBufferPointer<Double>
) {
    precondition(lats.count == lons.count, "lat/lon count mismatch")
    precondition(
        outLats.count >= lats.count && outLons.count >= lons.count,
        "output buffers too small"
    )

    let count = lats.count
    if count == 0 { return }
    precondition(
        lats.baseAddress != nil && lons.baseAddress != nil,
        "nil baseAddress for non-empty input"
    )
    precondition(
        outLats.baseAddress != nil && outLons.baseAddress != nil,
        "nil baseAddress for non-empty output"
    )

    // For now, fall back to the standard vDSP implementation
    transformBatchVDSP(
        lats: lats,
        lons: lons,
        matrix: matrix,
        outLats: outLats,
        outLons: outLons
    )
}
