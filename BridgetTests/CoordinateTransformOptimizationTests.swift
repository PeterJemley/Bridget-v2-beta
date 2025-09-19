//
//  CoordinateTransformOptimizationTests.swift
//  BridgetTests
//
//  Purpose: Property tests for coordinate transformation optimizations
//  Dependencies: Testing, Foundation, Accelerate, simd
//  Integration Points:
//    - Tests SIMD vs vDSP agreement within 1e-12 tolerance
//    - Validates optimization correctness
//    - Ensures double precision end-to-end
//  Key Features:
//    - Property-based testing with random inputs
//    - Accuracy verification for all optimization paths
//    - Performance regression detection
//  Additional Features:
//    - Deterministic RNG for reproducible tests
//    - Environment overridable tolerance configuration
//    - Error metric tracking and reporting for diagnostics
//
//  Usage (Environment Variables):
//    - TEST_ABS_TOL: Override absolute tolerance (e.g., 1e-11)
//    - TEST_REL_TOL: Override relative tolerance (e.g., 3e-10)
//    - TEST_RANDOM_SEED: Seed for deterministic random inputs (e.g., 12345)
//    - ENABLE_PERF_TESTS: Enable heavy performance tests (true/1/yes/on)
//    - TEST_MAX_ULP: Optional ULP threshold; if set, tests will fail when max observed ULP exceeds this value
//
//  Examples:
//    TEST_ABS_TOL=1e-11 TEST_REL_TOL=3e-10 xcodebuild test -scheme Bridget
//    TEST_RANDOM_SEED=12345 swift test
//    ENABLE_PERF_TESTS=true xcodebuild test -scheme Bridget
//    TEST_MAX_ULP=512 swift test
//

#if canImport(Testing)
    import Testing
    import Foundation
    import Accelerate
    import simd
    @testable import Bridget

    // MARK: - Test Configuration
    private let kEnablePerfEnvKey = "ENABLE_PERF_TESTS"
    private let kSeedEnvKey = "TEST_RANDOM_SEED"
    private let kTolAbsEnvKey = "TEST_ABS_TOL"
    private let kTolRelEnvKey = "TEST_REL_TOL"
    private let kMaxUlpEnvKey = "TEST_MAX_ULP"

    @inline(__always)
    private func isPerformanceTestsEnabled() -> Bool {
        if let raw = ProcessInfo.processInfo.environment[kEnablePerfEnvKey] {
            switch raw.lowercased() {
            case "1", "true", "yes", "on": return true
            default: return false
            }
        }
        return false
    }

    @inline(__always)
    private func envDouble(_ key: String, default def: Double) -> Double {
        if let raw = ProcessInfo.processInfo.environment[key],
            let v = Double(raw)
        {
            return v
        }
        return def
    }

    @inline(__always)
    private func envUInt64(_ key: String) -> UInt64? {
        if let raw = ProcessInfo.processInfo.environment[key],
            let v = UInt64(raw)
        {
            return v
        }
        return nil
    }

    private let kDefaultAbsTol: Double = envDouble(
        kTolAbsEnvKey,
        default: 1e-12
    )
    private let kDefaultRelTol: Double = envDouble(
        kTolRelEnvKey,
        default: 1e-10
    )

    private let kMaxULPThreshold: UInt64? = envUInt64(kMaxUlpEnvKey)

    private let kDefaultSeed: UInt64 = {
        if let raw = ProcessInfo.processInfo.environment[kSeedEnvKey],
            let v = UInt64(raw)
        {
            return v
        }
        return 0x9E37_79B9_7F4A_7C15  // golden ratio-ish default
    }()

    private struct XorShift64Star: RandomNumberGenerator {
        private var state: UInt64
        init(seed: UInt64) {
            self.state = seed == 0 ? 0xDEAD_BEEF_CAFE_BABE : seed
        }
        mutating func next() -> UInt64 {
            var x = state
            x ^= x >> 12
            x ^= x << 25
            x ^= x >> 27
            state = x
            return x &* 2_685_821_657_736_338_717
        }
    }

    @Suite("Coordinate Transform Optimization Tests")
    struct CoordinateTransformOptimizationTests {
        static func setup() {
            print(
                "[Test Config] absTol=\(kDefaultAbsTol) relTol=\(kDefaultRelTol) seed=\(kDefaultSeed) perf=\(isPerformanceTestsEnabled()) maxULP=\(kMaxULPThreshold.map(String.init) ?? "nil")"
            )
        }

        @Test("SIMD vs Scalar Agreement - Single Points")
        func simdVsScalarAgreement() async throws {
            Self.setup()
            var maxAbsErr = 0.0
            var maxRelErr = 0.0
            var observedMaxULP: UInt64 = 0

            let testPoints = generateTestPoints(count: 1000)
            let testMatrices = generateTestMatrices(count: 100)

            for matrix in testMatrices {
                for (lat, lon) in testPoints {
                    let simdResult = applyTransformationSIMD(
                        latitude: lat,
                        longitude: lon,
                        matrix: matrix
                    )

                    let scalarResult = applyScalar(
                        lat: lat,
                        lon: lon,
                        matrix: matrix
                    )

                    #expect(
                        nearlyEqualTuple(
                            simdResult,
                            scalarResult,
                            absTol: kDefaultAbsTol,
                            relTol: kDefaultRelTol
                        ),
                        "SIMD and scalar results must agree within mixed tolerances"
                    )

                    let a1 = abs(simdResult.0 - scalarResult.0)
                    let a2 = abs(simdResult.1 - scalarResult.1)
                    let s1 = max(abs(simdResult.0), abs(scalarResult.0))
                    let s2 = max(abs(simdResult.1), abs(scalarResult.1))
                    maxAbsErr = max(maxAbsErr, a1, a2)
                    maxRelErr = max(
                        maxRelErr,
                        a1 / max(s1, .ulpOfOne),
                        a2 / max(s2, .ulpOfOne)
                    )
                    observedMaxULP = max(
                        observedMaxULP,
                        ulpDistance(simdResult.0, scalarResult.0),
                        ulpDistance(simdResult.1, scalarResult.1)
                    )
                }
            }

            print(
                "[Metrics] SIMDvsScalar: maxAbs=\(maxAbsErr) maxRel=\(maxRelErr) maxULP=\(observedMaxULP)"
            )

            if let maxULP = kMaxULPThreshold {
                #expect(
                    maxULP >= observedMaxULP,
                    "Max ULP (\(observedMaxULP)) exceeded threshold (\(maxULP)) in SIMDvsScalar"
                )
            }
        }

        @Test("vDSP vs SIMD Agreement - Batch Processing")
        func vdspVsSimdAgreement() async throws {
            Self.setup()
            var maxAbsErr = 0.0
            var maxRelErr = 0.0
            var observedMaxULP: UInt64 = 0

            let testPoints = generateTestPoints(count: 1000)
            let testMatrices = generateTestMatrices(count: 10)

            for matrix in testMatrices {
                // Prepare input arrays
                let lats = testPoints.map { $0.0 }
                let lons = testPoints.map { $0.1 }

                // SIMD results
                var simdLats = [Double](repeating: 0, count: testPoints.count)
                var simdLons = [Double](repeating: 0, count: testPoints.count)

                for i in 0..<testPoints.count {
                    let result = applyTransformationSIMD(
                        latitude: lats[i],
                        longitude: lons[i],
                        matrix: matrix
                    )
                    simdLats[i] = result.0
                    simdLons[i] = result.1
                }

                // vDSP results
                var vdspLats = [Double](repeating: 0, count: testPoints.count)
                var vdspLons = [Double](repeating: 0, count: testPoints.count)

                lats.withUnsafeBufferPointer { latPtr in
                    lons.withUnsafeBufferPointer { lonPtr in
                        vdspLats.withUnsafeMutableBufferPointer { outLatPtr in
                            vdspLons.withUnsafeMutableBufferPointer {
                                outLonPtr in
                                transformBatchVDSP(
                                    lats: latPtr,
                                    lons: lonPtr,
                                    matrix: matrix,
                                    outLats: outLatPtr,
                                    outLons: outLonPtr
                                )
                            }
                        }
                    }
                }

                // Compare results
                for i in 0..<testPoints.count {
                    #expect(
                        nearlyEqualTuple(
                            (simdLats[i], simdLons[i]),
                            (vdspLats[i], vdspLons[i]),
                            absTol: kDefaultAbsTol,
                            relTol: kDefaultRelTol
                        ),
                        "vDSP and SIMD batch results must agree within mixed tolerances at index \(i)"
                    )

                    let a1 = abs(simdLats[i] - vdspLats[i])
                    let a2 = abs(simdLons[i] - vdspLons[i])
                    let s1 = max(abs(simdLats[i]), abs(vdspLats[i]))
                    let s2 = max(abs(simdLons[i]), abs(vdspLons[i]))
                    maxAbsErr = max(maxAbsErr, a1, a2)
                    maxRelErr = max(
                        maxRelErr,
                        a1 / max(s1, .ulpOfOne),
                        a2 / max(s2, .ulpOfOne)
                    )
                    observedMaxULP = max(
                        observedMaxULP,
                        ulpDistance(simdLats[i], vdspLats[i]),
                        ulpDistance(simdLons[i], vdspLons[i])
                    )
                }
            }

            print(
                "[Metrics] vDSPvsSIMD: maxAbs=\(maxAbsErr) maxRel=\(maxRelErr) maxULP=\(observedMaxULP)"
            )

            if let maxULP = kMaxULPThreshold {
                #expect(
                    maxULP >= observedMaxULP,
                    "Max ULP (\(observedMaxULP)) exceeded threshold (\(maxULP)) in vDSPvsSIMD"
                )
            }
        }

        @Test("vDSP 3x3 vs Standard Agreement - Batch Processing")
        func vdsp3x3VsStandardAgreement() async throws {
            Self.setup()
            var maxAbsErr = 0.0
            var maxRelErr = 0.0
            var observedMaxULP: UInt64 = 0

            let testPoints = generateTestPoints(count: 1000)
            let testMatrices = generateTestMatrices(count: 10)

            for matrix in testMatrices {
                // Prepare input arrays
                let lats = testPoints.map { $0.0 }
                let lons = testPoints.map { $0.1 }

                // Standard vDSP results
                var standardLats = [Double](
                    repeating: 0,
                    count: testPoints.count
                )
                var standardLons = [Double](
                    repeating: 0,
                    count: testPoints.count
                )

                lats.withUnsafeBufferPointer { latPtr in
                    lons.withUnsafeBufferPointer { lonPtr in
                        standardLats.withUnsafeMutableBufferPointer {
                            outLatPtr in
                            standardLons.withUnsafeMutableBufferPointer {
                                outLonPtr in
                                transformBatchVDSP(
                                    lats: latPtr,
                                    lons: lonPtr,
                                    matrix: matrix,
                                    outLats: outLatPtr,
                                    outLons: outLonPtr
                                )
                            }
                        }
                    }
                }

                // vDSP 3x3 results
                var vdsp3x3Lats = [Double](
                    repeating: 0,
                    count: testPoints.count
                )
                var vdsp3x3Lons = [Double](
                    repeating: 0,
                    count: testPoints.count
                )

                lats.withUnsafeBufferPointer { latPtr in
                    lons.withUnsafeBufferPointer { lonPtr in
                        vdsp3x3Lats.withUnsafeMutableBufferPointer {
                            outLatPtr in
                            vdsp3x3Lons.withUnsafeMutableBufferPointer {
                                outLonPtr in
                                transformBatchVDSP3x3(
                                    lats: latPtr,
                                    lons: lonPtr,
                                    matrix: matrix,
                                    outLats: outLatPtr,
                                    outLons: outLonPtr
                                )
                            }
                        }
                    }
                }

                // Compare results
                for i in 0..<testPoints.count {
                    #expect(
                        nearlyEqualTuple(
                            (standardLats[i], standardLons[i]),
                            (vdsp3x3Lats[i], vdsp3x3Lons[i]),
                            absTol: kDefaultAbsTol,
                            relTol: kDefaultRelTol
                        ),
                        "vDSP 3x3 and standard vDSP results must agree within mixed tolerances at index \(i)"
                    )

                    let a1 = abs(standardLats[i] - vdsp3x3Lats[i])
                    let a2 = abs(standardLons[i] - vdsp3x3Lons[i])
                    let s1 = max(abs(standardLats[i]), abs(vdsp3x3Lats[i]))
                    let s2 = max(abs(standardLons[i]), abs(vdsp3x3Lons[i]))
                    maxAbsErr = max(maxAbsErr, a1, a2)
                    maxRelErr = max(
                        maxRelErr,
                        a1 / max(s1, .ulpOfOne),
                        a2 / max(s2, .ulpOfOne)
                    )
                    observedMaxULP = max(
                        observedMaxULP,
                        ulpDistance(standardLats[i], vdsp3x3Lats[i]),
                        ulpDistance(standardLons[i], vdsp3x3Lons[i])
                    )
                }
            }

            print(
                "[Metrics] vDSP3x3vsStd: maxAbs=\(maxAbsErr) maxRel=\(maxRelErr) maxULP=\(observedMaxULP)"
            )

            if let maxULP = kMaxULPThreshold {
                #expect(
                    maxULP >= observedMaxULP,
                    "Max ULP (\(observedMaxULP)) exceeded threshold (\(maxULP)) in vDSP3x3vsStd"
                )
            }
        }

        @Test("Double Precision Maintained - Edge Cases")
        func doublePrecisionMaintained() async throws {
            Self.setup()
            // Test with very small and very large numbers
            let edgeCases: [(Double, Double)] = [
                (1e-15, 1e-15),  // Very small
                (1e15, 1e15),  // Very large
                (0.0, 0.0),  // Zero
                (-1e-10, 1e-10),  // Mixed small
                (1e-5, -1e-5),  // Mixed small negative
            ]

            let testMatrix = TransformationMatrix(
                latOffset: 1e-12,
                lonOffset: -1e-12,
                latScale: 1.0 + 1e-15,
                lonScale: 1.0 - 1e-15,
                rotation: 1e-10
            )

            for (lat, lon) in edgeCases {
                let simdResult = applyTransformationSIMD(
                    latitude: lat,
                    longitude: lon,
                    matrix: testMatrix
                )

                let scalarResult = applyScalar(
                    lat: lat,
                    lon: lon,
                    matrix: testMatrix
                )

                #expect(
                    nearlyEqualTuple(
                        simdResult,
                        scalarResult,
                        absTol: kDefaultAbsTol,
                        relTol: kDefaultRelTol
                    ),
                    "Double precision must be maintained within mixed tolerances for edge case (\(lat), \(lon))"
                )
            }
        }

        @Test("Performance Regression Detection")
        func performanceRegressionDetection() async throws {
            Self.setup()
            guard isPerformanceTestsEnabled() else {
                // Skip heavy performance test unless explicitly enabled
                print(
                    "[SKIP] performanceRegressionDetection because \(kEnablePerfEnvKey)=true not set"
                )
                return
            }
            let testPoints = generateTestPoints(count: 3000)
            let testMatrix = TransformationMatrix(
                latOffset: 0.001,
                lonOffset: -0.001,
                latScale: 1.001,
                lonScale: 0.999,
                rotation: 0.1
            )

            // Measure SIMD performance
            let simdStart = CFAbsoluteTimeGetCurrent()
            for (lat, lon) in testPoints {
                _ = applyTransformationSIMD(
                    latitude: lat,
                    longitude: lon,
                    matrix: testMatrix
                )
            }
            let simdTime = CFAbsoluteTimeGetCurrent() - simdStart

            // Measure scalar performance
            let scalarStart = CFAbsoluteTimeGetCurrent()
            for (lat, lon) in testPoints {
                _ = applyScalar(
                    lat: lat,
                    lon: lon,
                    matrix: testMatrix
                )
            }
            let scalarTime = CFAbsoluteTimeGetCurrent() - scalarStart

            // SIMD should be at least as fast as scalar (allowing for measurement variance)
            #expect(
                simdTime <= scalarTime * 1.1,
                "SIMD should not be significantly slower than scalar"
            )

            // Log performance for monitoring
            print(
                "SIMD time: \(simdTime)s, Scalar time: \(scalarTime)s, Speedup: \(scalarTime / simdTime)x"
            )
        }

        @Test("Batch Processing Performance")
        func batchProcessingPerformance() async throws {
            Self.setup()
            guard isPerformanceTestsEnabled() else {
                // Skip heavy performance test unless explicitly enabled
                print(
                    "[SKIP] batchProcessingPerformance because \(kEnablePerfEnvKey)=true not set"
                )
                return
            }
            let testPoints = generateTestPoints(count: 3000)
            let testMatrix = TransformationMatrix(
                latOffset: 0.001,
                lonOffset: -0.001,
                latScale: 1.001,
                lonScale: 0.999,
                rotation: 0.1
            )

            let lats = testPoints.map { $0.0 }
            let lons = testPoints.map { $0.1 }

            // Measure vDSP batch performance
            var vdspLats = [Double](repeating: 0, count: testPoints.count)
            var vdspLons = [Double](repeating: 0, count: testPoints.count)

            let vdspStart = CFAbsoluteTimeGetCurrent()
            lats.withUnsafeBufferPointer { latPtr in
                lons.withUnsafeBufferPointer { lonPtr in
                    vdspLats.withUnsafeMutableBufferPointer { outLatPtr in
                        vdspLons.withUnsafeMutableBufferPointer { outLonPtr in
                            transformBatchVDSP(
                                lats: latPtr,
                                lons: lonPtr,
                                matrix: testMatrix,
                                outLats: outLatPtr,
                                outLons: outLonPtr
                            )
                        }
                    }
                }
            }
            let vdspTime = CFAbsoluteTimeGetCurrent() - vdspStart

            // Measure individual SIMD performance
            let simdStart = CFAbsoluteTimeGetCurrent()
            for i in 0..<testPoints.count {
                _ = applyTransformationSIMD(
                    latitude: lats[i],
                    longitude: lons[i],
                    matrix: testMatrix
                )
            }
            let simdTime = CFAbsoluteTimeGetCurrent() - simdStart

            // vDSP batch should be significantly faster than individual SIMD calls
            #expect(
                vdspTime <= simdTime * 0.9,
                "vDSP batch should be faster than or comparable to individual SIMD calls"
            )

            // Log performance for monitoring
            print(
                "vDSP batch time: \(vdspTime)s, Individual SIMD time: \(simdTime)s, Speedup: \(simdTime / vdspTime)x"
            )
        }
    }

    // MARK: - Local Robust Comparison Helpers

    /// Mixed absolute/relative tolerance comparison for doubles
    @inline(__always)
    private func nearlyEqual(
        _ a: Double,
        _ b: Double,
        absTol: Double = 1e-12,
        relTol: Double = 1e-10
    ) -> Bool {
        if a == b { return true }
        let diff = abs(a - b)
        if diff <= absTol { return true }
        let scale = max(abs(a), abs(b))
        return diff <= relTol * scale
    }

    /// Tuple comparison using mixed tolerance
    @inline(__always)
    private func nearlyEqualTuple(
        _ r1: (Double, Double),
        _ r2: (Double, Double),
        absTol: Double = 1e-12,
        relTol: Double = 1e-10
    ) -> Bool {
        return nearlyEqual(r1.0, r2.0, absTol: absTol, relTol: relTol)
            && nearlyEqual(r1.1, r2.1, absTol: absTol, relTol: relTol)
    }

    @inline(__always)
    private func ulpDistance(_ a: Double, _ b: Double) -> UInt64 {
        if a.isNaN || b.isNaN { return UInt64.max }
        if a == b { return 0 }
        let ai = a.bitPattern ^ ((a.bitPattern >> 63) & 0x7fff_ffff_ffff_ffff)
        let bi = b.bitPattern ^ ((b.bitPattern >> 63) & 0x7fff_ffff_ffff_ffff)
        return ai > bi ? ai - bi : bi - ai
    }

    @inline(__always)
    private func nearlyEqualWithULP(
        _ a: Double,
        _ b: Double,
        absTol: Double,
        relTol: Double,
        maxULP: UInt64 = 256
    ) -> Bool {
        if nearlyEqual(a, b, absTol: absTol, relTol: relTol) { return true }
        return ulpDistance(a, b) <= maxULP
    }

    // MARK: - Test Data Generation

    /// Generate test points for property testing
    private func generateTestPoints(count: Int) -> [(Double, Double)] {
        var points: [(Double, Double)] = []
        points.reserveCapacity(count)

        // Generate points around Seattle area with some variation
        let baseLat = 47.6062
        let baseLon = -122.3321
        let latRange = 0.1  // ~11km
        let lonRange = 0.1  // ~8km

        var rng = XorShift64Star(seed: kDefaultSeed ^ 0xA5A5_A5A5_A5A5_A5A5)

        for _ in 0..<count {
            let lat =
                baseLat + Double.random(in: -latRange...latRange, using: &rng)
            let lon =
                baseLon + Double.random(in: -lonRange...lonRange, using: &rng)
            points.append((lat, lon))
        }

        return points
    }

    /// Generate test transformation matrices for property testing
    private func generateTestMatrices(count: Int) -> [TransformationMatrix] {
        var matrices: [TransformationMatrix] = []
        matrices.reserveCapacity(count)

        var rng = XorShift64Star(seed: kDefaultSeed ^ 0xC3C3_C3C3_C3C3_C3C3)

        for _ in 0..<count {
            let matrix = TransformationMatrix(
                latOffset: Double.random(in: -0.01...0.01, using: &rng),  // ~1km range
                lonOffset: Double.random(in: -0.01...0.01, using: &rng),  // ~1km range
                latScale: Double.random(in: 0.99...1.01, using: &rng),  // Small scaling
                lonScale: Double.random(in: 0.99...1.01, using: &rng),  // Small scaling
                rotation: Double.random(in: -1.0...1.0, using: &rng)  // Small rotation in degrees
            )
            matrices.append(matrix)
        }

        return matrices
    }

    // MARK: - Helper Functions (reused from optimized implementation)

    /// Scalar transformation for comparison (reused from existing implementation)
    @inline(__always)
    private func applyScalar(
        lat: Double,
        lon: Double,
        matrix: TransformationMatrix
    ) -> (Double, Double) {
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

#endif
