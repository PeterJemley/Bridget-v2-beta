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

internal extension DefaultCoordinateTransformService {
    /// Applies a transformation matrix to a single lat/lon point (scalar path).
    /// Matrix layout:
    /// [ m00, m01, tx,
    ///   m10, m11, ty ]
    /// Returns transformed (lat, lon)
    func applyMatrixScalar(lat: Double, lon: Double, matrix: [Double]) -> (Double, Double) {
        // matrix must have 6 elements
        precondition(matrix.count == 6)
        let m00 = matrix[0]
        let m01 = matrix[1]
        let tx  = matrix[2]
        let m10 = matrix[3]
        let m11 = matrix[4]
        let ty  = matrix[5]
        let x = lat
        let y = lon
        let newX = m00 * x + m01 * y + tx
        let newY = m10 * x + m11 * y + ty
        return (newX, newY)
    }

    /// Applies a transformation chunk using Accelerate for the 3xN matrix multiply + translation when rotation == 0.
    /// When rotation != 0, fallback to scalar loop.
    ///
    /// The matrix layout is the same as above.
    /// Inputs:
    /// - lats, lons: input arrays (all same length)
    /// - matrix: transform matrix (6 elements)
    /// - resultLats, resultLons: output arrays, must have capacity >= input count
    func transformChunkVDSP(
        lats: UnsafeBufferPointer<Double>,
        lons: UnsafeBufferPointer<Double>,
        matrix: [Double],
        resultLats: UnsafeMutableBufferPointer<Double>,
        resultLons: UnsafeMutableBufferPointer<Double>
    ) {
        precondition(matrix.count == 6)
        precondition(lats.count == lons.count)
        precondition(resultLats.count >= lats.count)
        precondition(resultLons.count >= lons.count)

        // determine if rotation is zero (m01 and m10)
        let rotationZero = matrix[1] == 0 && matrix[3] == 0

        if rotationZero {
            // matrix:
            // m00 m01 tx
            // m10 m11 ty
            // m01 == 0, m10 == 0
            // So transform simplifies to:
            // newX = m00 * x + tx
            // newY = m11 * y + ty
            let count = lats.count
            let m00 = matrix[0]
            let m11 = matrix[4]
            let tx = matrix[2]
            let ty = matrix[5]

            // vDSP supports vectorized multiply + add
            // newX = m00 * lats + tx
            // newY = m11 * lons + ty

            // temp buffer for newX
            var newX = [Double](repeating: 0, count: count)
            var newY = [Double](repeating: 0, count: count)
            vDSP_vsmulD(lats.baseAddress!, 1, [m00], &newX, 1, vDSP_Length(count))
            vDSP_vsaddD(newX, 1, [tx], &newX, 1, vDSP_Length(count))

            vDSP_vsmulD(lons.baseAddress!, 1, [m11], &newY, 1, vDSP_Length(count))
            vDSP_vsaddD(newY, 1, [ty], &newY, 1, vDSP_Length(count))

            for i in 0..<count {
                resultLats[i] = newX[i]
                resultLons[i] = newY[i]
            }
        } else {
            // Fallback scalar loop for rotation != 0
            let count = lats.count
            for i in 0..<count {
                let lat = lats[i]
                let lon = lons[i]
                let (tx, ty) = applyMatrixScalar(lat: lat, lon: lon, matrix: matrix)
                resultLats[i] = tx
                resultLons[i] = ty
            }
        }
    }
}

public extension DefaultCoordinateTransformService {
    /// Batch transform points from source to target coordinate system using optional TransformCache and concurrency.
    ///
    /// - Parameters:
    ///   - points: Array of BatchPoint to transform.
    ///   - source: Source CoordinateSystem.
    ///   - target: Target CoordinateSystem.
    ///   - bridgeId: Optional bridge id to use in matrix calculation.
    ///   - pointCache: Optional TransformCache to use for caching transformed points.
    ///   - chunkSize: Size of chunks to split points for concurrent transforms.
    ///   - concurrencyCap: Max concurrent tasks to run.
    /// - Returns: BatchResult with transformed points in original order.
    func transformBatch(
        points: [BatchPoint],
        from source: CoordinateSystem,
        to target: CoordinateSystem,
        bridgeId: String?,
        pointCache: TransformCache? = nil,
        chunkSize: Int = 1024,
        concurrencyCap: Int = 4
    ) async throws -> BatchResult {
        guard points.count > 0 else {
            return BatchResult(points: [])
        }

        // If less than 32 points, fast single-threaded path
        if points.count < 32 {
            // Obtain matrix once on main actor
            let matrix = await MainActor.run {
                calculateTransformationMatrix(from: source, to: target, bridgeId: bridgeId)
            }
            var results = [(Double, Double)]()
            results.reserveCapacity(points.count)
            let cachingEnabled = pointCache?.isPointCacheEnabled ?? false

            for p in points {
                if cachingEnabled, let pointCache = pointCache {
                    let pointKey = pointCache.createPointKey(lat: p.lat, lon: p.lon)
                    if let cached = pointCache.getPoint(for: pointKey) {
                        results.append(cached)
                        continue
                    }
                }

                let transformed = applyMatrixScalar(lat: p.lat, lon: p.lon, matrix: matrix)

                if cachingEnabled, let pointCache = pointCache {
                    let pointKey = pointCache.createPointKey(lat: p.lat, lon: p.lon)
                    pointCache.setPoint(transformed, for: pointKey)
                }

                results.append(transformed)
            }
            return BatchResult(points: results)
        }

        // For >= 32 points: batch concurrent path

        // Group points by (source, target, bridgeId) - in this context, source/target/bridgeId are fixed per call,
        // so all points share same key. So grouping is trivial: all points in one group.
        // However, instructions say to group by (source, target, bridgeId),
        // but since these are call parameters, group is a single group.

        // We'll chunk points into batches of chunkSize for concurrency.

        let cpuCount = ProcessInfo.processInfo.activeProcessorCount
        let concurrencyLimit = min(concurrencyCap, max(cpuCount, 1))

        // Result buffer pre-allocated to points.count, to store results in order
        var results = Array<(Double, Double)?>(repeating: nil, count: points.count)

        // Caching enabled flag
        let cachingEnabled = pointCache?.isPointCacheEnabled ?? false

        // Obtain transformation matrix once, on main actor
        let matrix = await MainActor.run {
            calculateTransformationMatrix(from: source, to: target, bridgeId: bridgeId)
        }

        // Helper closure for transforming a chunk
        func transformChunk(startIndex: Int, endIndex: Int) {
            let length = endIndex - startIndex
            guard length > 0 else { return }
            let chunkPoints = points[startIndex..<endIndex]

            // Prepare input buffers
            var lats = [Double]()
            var lons = [Double]()
            lats.reserveCapacity(length)
            lons.reserveCapacity(length)
            for p in chunkPoints {
                lats.append(p.lat)
                lons.append(p.lon)
            }

            var transformedLats = [Double](repeating: 0, count: length)
            var transformedLons = [Double](repeating: 0, count: length)

            // We'll use vectorized path if no rotation and length >= 32
            let rotationZero = matrix[1] == 0 && matrix[3] == 0
            if length >= 32 && rotationZero {
                lats.withUnsafeBufferPointer { latPtr in
                    lons.withUnsafeBufferPointer { lonPtr in
                        transformedLats.withUnsafeMutableBufferPointer { outLatPtr in
                            transformedLons.withUnsafeMutableBufferPointer { outLonPtr in
                                transformChunkVDSP(
                                    lats: latPtr,
                                    lons: lonPtr,
                                    matrix: matrix,
                                    resultLats: outLatPtr,
                                    resultLons: outLonPtr
                                )
                            }
                        }
                    }
                }
            } else {
                // fallback scalar loop
                for i in 0..<length {
                    let lat = lats[i]
                    let lon = lons[i]
                    let (tx, ty) = applyMatrixScalar(lat: lat, lon: lon, matrix: matrix)
                    transformedLats[i] = tx
                    transformedLons[i] = ty
                }
            }

            // Cache and store results in original order
            for i in 0..<length {
                let originalIndex = startIndex + i
                let originalPoint = points[originalIndex]
                let transformedPoint = (transformedLats[i], transformedLons[i])

                if cachingEnabled, let pointCache = pointCache {
                    let pointKey = pointCache.createPointKey(lat: originalPoint.lat, lon: originalPoint.lon)
                    pointCache.setPoint(transformedPoint, for: pointKey)
                }
                results[originalIndex] = transformedPoint
            }
        }

        // Before launching concurrent tasks: try to use cache to fill results first
        if cachingEnabled, let pointCache = pointCache {
            var cachedCount = 0
            for (idx, p) in points.enumerated() {
                let key = pointCache.createPointKey(lat: p.lat, lon: p.lon)
                if let cached = pointCache.getPoint(for: key) {
                    results[idx] = cached
                    cachedCount += 1
                }
            }
            // If all cached, early return
            if cachedCount == points.count {
                return BatchResult(points: results.compactMap { $0 })
            }
        }

        // Launch concurrent transform tasks on chunks that are not cached yet
        // Build list of ranges to process (those points with nil in results)
        var uncachedRanges = [(start: Int, end: Int)]()
        var scanStart: Int? = nil
        for i in 0..<points.count {
            if results[i] == nil {
                if scanStart == nil {
                    scanStart = i
                }
            } else {
                if let start = scanStart {
                    uncachedRanges.append((start, i))
                    scanStart = nil
                }
            }
        }
        if let start = scanStart {
            uncachedRanges.append((start, points.count))
        }

        // For each uncached range, split into chunks of chunkSize
        var chunks = [(start: Int, end: Int)]()
        for range in uncachedRanges {
            var currentStart = range.start
            while currentStart < range.end {
                let currentEnd = min(currentStart + chunkSize, range.end)
                chunks.append((currentStart, currentEnd))
                currentStart = currentEnd
            }
        }

        // Concurrency-limited task group
        try await withTaskGroup(of: Void.self, returning: Void.self) { group in
            var runningTasks = 0
            var chunkIndex = 0

            func scheduleNext() {
                while runningTasks < concurrencyLimit && chunkIndex < chunks.count {
                    let (start, end) = chunks[chunkIndex]
                    chunkIndex += 1
                    runningTasks += 1
                    group.addTask {
                        transformChunk(startIndex: start, endIndex: end)
                        runningTasks -= 1
                    }
                }
            }

            scheduleNext()

            for await _ in group { 
                // When a task completes, try schedule next
                scheduleNext()
            }
        }

        // At this point, all results non-nil
        let finalResults = results.compactMap { $0 }
        return BatchResult(points: finalResults)
    }
}
