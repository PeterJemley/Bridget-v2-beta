import Foundation
import Accelerate

public struct BatchPoint: Sendable {
    public let lat: Double
    public let lon: Double
    public init(lat: Double, lon: Double) {
        self.lat = lat
        self.lon = lon
    }
}

public struct BatchResult: Sendable {
    public let points: [(Double, Double)]
    public init(points: [(Double, Double)]) {
        self.points = points
    }
}

// MARK: - File-private helpers (non-actor isolated)

@inline(__always)
fileprivate func applyScalar(lat: Double, lon: Double, matrix: TransformationMatrix) -> (Double, Double) {
    // Apply translation
    var tLat = lat + matrix.latOffset
    var tLon = lon + matrix.lonOffset

    // Apply scaling
    tLat *= matrix.latScale
    tLon *= matrix.lonScale

    // Apply rotation (simplified - assumes small angles), if any
    if matrix.rotation != 0.0 {
        let rotationRad = matrix.rotation * .pi / 180.0
        let cosRot = cos(rotationRad)
        let sinRot = sin(rotationRad)

        let latRad = tLat * .pi / 180.0
        let lonRad = tLon * .pi / 180.0

        let newLatRad = latRad * cosRot - lonRad * sinRot
        let newLonRad = latRad * sinRot + lonRad * cosRot

        tLat = newLatRad * 180.0 / .pi
        tLon = newLonRad * 180.0 / .pi
    }

    return (tLat, tLon)
}

fileprivate func transformChunkVectorized(
    lats: UnsafeBufferPointer<Double>,
    lons: UnsafeBufferPointer<Double>,
    matrix: TransformationMatrix,
    outLats: UnsafeMutableBufferPointer<Double>,
    outLons: UnsafeMutableBufferPointer<Double>
) {
    precondition(lats.count == lons.count)
    precondition(outLats.count >= lats.count)
    precondition(outLons.count >= lons.count)

    let count = lats.count

    // If rotation is zero, we can apply translation+scale independently per axis with vDSP
    if matrix.rotation == 0.0 {
        // newLat = (lat + latOffset) * latScale
        // newLon = (lon + lonOffset) * lonScale
        var tmpLat = [Double](repeating: 0, count: count)
        var tmpLon = [Double](repeating: 0, count: count)

        // tmpLat = lat + latOffset
        vDSP_vsaddD(lats.baseAddress!, 1, [matrix.latOffset], &tmpLat, 1, vDSP_Length(count))
        // outLat = tmpLat * latScale
        vDSP_vsmulD(tmpLat, 1, [matrix.latScale], outLats.baseAddress!, 1, vDSP_Length(count))

        // tmpLon = lon + lonOffset
        vDSP_vsaddD(lons.baseAddress!, 1, [matrix.lonOffset], &tmpLon, 1, vDSP_Length(count))
        // outLon = tmpLon * lonScale
        vDSP_vsmulD(tmpLon, 1, [matrix.lonScale], outLons.baseAddress!, 1, vDSP_Length(count))
    } else {
        // Fallback to scalar per element when rotation present
        for i in 0..<count {
            let (tLat, tLon) = applyScalar(lat: lats[i], lon: lons[i], matrix: matrix)
            outLats[i] = tLat
            outLons[i] = tLon
        }
    }
}

public extension DefaultCoordinateTransformService {
    /// Batch transform points from source to target coordinate system using optional TransformCache and concurrency.
    func transformBatch(
        points: [BatchPoint],
        from source: CoordinateSystem,
        to target: CoordinateSystem,
        bridgeId: String?,
        pointCache: Any? = nil,
        chunkSize: Int = 1024,
        concurrencyCap: Int = 4
    ) async throws -> BatchResult {
        let t0 = CFAbsoluteTimeGetCurrent()

        guard !points.isEmpty else { return BatchResult(points: []) }

        // Obtain matrix once on main actor when available; fall back for pre–iOS 13
        let matrixOpt: TransformationMatrix?
        if #available(iOS 13.0, *) {
            matrixOpt = await MainActor.run {
                calculateTransformationMatrix(from: source, to: target, bridgeId: bridgeId)
            }
        } else {
            // On older OS versions where MainActor.run isn't available, call directly.
            matrixOpt = calculateTransformationMatrix(from: source, to: target, bridgeId: bridgeId)
        }
        guard let matrix = matrixOpt else {
            throw TransformationError.transformationCalculationFailed
        }

        // Small input: scalar path
        if points.count < 32 {
            var results: [(Double, Double)] = []
            results.reserveCapacity(points.count)

            for p in points {
                // Try cache first (if provided and available on this OS)
                if #available(iOS 26.0, *), let cache = pointCache as? TransformCache {
                    let key = await cache.createPointKey(
                        source: source,
                        target: target,
                        bridgeId: bridgeId,
                        lat: p.lat,
                        lon: p.lon
                    )
                    if let cached = await cache.getPoint(for: key) {
                        results.append(cached)
                        continue
                    }
                    let transformed = applyScalar(lat: p.lat, lon: p.lon, matrix: matrix)
                    await cache.setPoint(transformed, for: key)
                    results.append(transformed)
                } else {
                    results.append(applyScalar(lat: p.lat, lon: p.lon, matrix: matrix))
                }
            }

            let dt = CFAbsoluteTimeGetCurrent() - t0
            TransformMetrics.observe("batch_small_latency_seconds", dt)
            if dt > 0 {
                TransformMetrics.observe("batch_small_throughput_pts_per_s", Double(points.count) / dt)
            }

            return BatchResult(points: results)
        }

        // Large input: chunk + concurrency
        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        let concurrencyLimit = max(1, min(concurrencyCap, cpuCount))

        // Pre-allocate result array preserving order
        var results = Array<(Double, Double)?>(repeating: nil, count: points.count)

        // Attempt to fill from cache first (if provided)
        if #available(iOS 26.0, *), let cache = pointCache as? TransformCache {
            await withTaskGroup(of: Void.self) { group in
                for (i, p) in points.enumerated() {
                    group.addTask {
                        let key = await cache.createPointKey(
                            source: source,
                            target: target,
                            bridgeId: bridgeId,
                            lat: p.lat,
                            lon: p.lon
                        )
                        if let cached = await cache.getPoint(for: key) {
                            results[i] = cached
                        }
                    }
                }
            }
            // Early return if all cached
            if results.allSatisfy({ $0 != nil }) {
                return BatchResult(points: results.compactMap { $0 })
            }
        }

        // Build chunks for remaining indices
        var ranges: [(Int, Int)] = []
        var start: Int? = nil
        for i in 0..<points.count {
            if results[i] == nil {
                if start == nil { start = i }
            } else if let s = start {
                ranges.append((s, i))
                start = nil
            }
        }
        if let s = start { ranges.append((s, points.count)) }

        var chunks: [(Int, Int)] = []
        for (s, e) in ranges {
            var cs = s
            while cs < e {
                let ce = min(cs + chunkSize, e)
                chunks.append((cs, ce))
                cs = ce
            }
        }

        // Process chunks with concurrency limit
        if #available(iOS 13.0, *) {
            try await withThrowingTaskGroup(of: Void.self) { group in
                var next = 0
                var running = 0

                func schedule() {
                    while running < concurrencyLimit && next < chunks.count {
                        let (s, e) = chunks[next]
                        next += 1
                        running += 1
                        group.addTask {
                            defer { running -= 1 }

                            let length = e - s
                            var lats = [Double](repeating: 0, count: length)
                            var lons = [Double](repeating: 0, count: length)
                            for i in 0..<length {
                                lats[i] = points[s + i].lat
                                lons[i] = points[s + i].lon
                            }

                            var outLats = [Double](repeating: 0, count: length)
                            var outLons = [Double](repeating: 0, count: length)

                            lats.withUnsafeBufferPointer { latPtr in
                                lons.withUnsafeBufferPointer { lonPtr in
                                    outLats.withUnsafeMutableBufferPointer { oLat in
                                        outLons.withUnsafeMutableBufferPointer { oLon in
                                            transformChunkVectorized(
                                                lats: latPtr,
                                                lons: lonPtr,
                                                matrix: matrix,
                                                outLats: oLat,
                                                outLons: oLon
                                            )
                                        }
                                    }
                                }
                            }

                            // Write back and populate cache if provided
                            for i in 0..<length {
                                let idx = s + i
                                let pair = (outLats[i], outLons[i])
                                results[idx] = pair
                                if #available(iOS 26.0, *), let cache = pointCache as? TransformCache {
                                    let key = await cache.createPointKey(
                                        source: source,
                                        target: target,
                                        bridgeId: bridgeId,
                                        lat: points[idx].lat,
                                        lon: points[idx].lon
                                    )
                                    await cache.setPoint(pair, for: key)
                                }
                            }
                        }
                    }
                }

                schedule()
                while let _ = try await group.next() { schedule() }
            }
        } else {
            // Pre–iOS 13: sequential processing of chunks
            for (s, e) in chunks {
                let length = e - s
                var lats = [Double](repeating: 0, count: length)
                var lons = [Double](repeating: 0, count: length)
                for i in 0..<length {
                    lats[i] = points[s + i].lat
                    lons[i] = points[s + i].lon
                }

                var outLats = [Double](repeating: 0, count: length)
                var outLons = [Double](repeating: 0, count: length)

                lats.withUnsafeBufferPointer { latPtr in
                    lons.withUnsafeBufferPointer { lonPtr in
                        outLats.withUnsafeMutableBufferPointer { oLat in
                            outLons.withUnsafeMutableBufferPointer { oLon in
                                transformChunkVectorized(
                                    lats: latPtr,
                                    lons: lonPtr,
                                    matrix: matrix,
                                    outLats: oLat,
                                    outLons: oLon
                                )
                            }
                        }
                    }
                }

                for i in 0..<length {
                    let idx = s + i
                    let pair = (outLats[i], outLons[i])
                    results[idx] = pair
                    if #available(iOS 26.0, *), let cache = pointCache as? TransformCache {
                        let key = await cache.createPointKey(
                            source: source,
                            target: target,
                            bridgeId: bridgeId,
                            lat: points[idx].lat,
                            lon: points[idx].lon
                        )
                        await cache.setPoint(pair, for: key)
                    }
                }
            }
        }

        let dt = CFAbsoluteTimeGetCurrent() - t0
        TransformMetrics.observe("batch_latency_seconds", dt)
        if dt > 0 {
            TransformMetrics.observe("batch_throughput_pts_per_s", Double(points.count) / dt)
        }

        return BatchResult(points: results.compactMap { $0 })
    }
}
