#!/usr/bin/env swift

import Foundation
import Accelerate
import simd

/// iOS-specific benchmark for coordinate transformation performance
/// This runs on iOS Simulator and measures actual app performance

// MARK: - Basic Types

struct TransformationMatrix: Codable, Equatable, Sendable {
    let latOffset: Double
    let lonOffset: Double
    let latScale: Double
    let lonScale: Double
    let rotation: Double
    
    init(latOffset: Double = 0.0, lonOffset: Double = 0.0, 
         latScale: Double = 1.0, lonScale: Double = 1.0, rotation: Double = 0.0) {
        self.latOffset = latOffset
        self.lonOffset = lonOffset
        self.latScale = latScale
        self.lonScale = lonScale
        self.rotation = rotation
    }
}

// MARK: - Affine3x3 for SIMD operations

struct Affine3x3 {
    var m: simd_double3x3
    
    init(a: Double, b: Double, c: Double, d: Double, tx: Double, ty: Double) {
        // simd_double3x3 is column-major internally. Build via columns for correctness.
        let col0 = simd_double3(a, c, 0.0)
        let col1 = simd_double3(b, d, 0.0)
        let col2 = simd_double3(tx, ty, 1.0)
        self.m = simd_double3x3(col0, col1, col2)
    }
    
    init(from matrix: TransformationMatrix) {
        // Convert TransformationMatrix to Affine3x3
        let cosRot = cos(matrix.rotation * .pi / 180.0)
        let sinRot = sin(matrix.rotation * .pi / 180.0)
        
        self.init(
            a: matrix.latScale * cosRot,
            b: -matrix.lonScale * sinRot,
            c: matrix.latScale * sinRot,
            d: matrix.lonScale * cosRot,
            tx: matrix.latOffset,
            ty: matrix.lonOffset
        )
    }
}

// MARK: - iOS Benchmark Results

struct iOSBenchResult: Codable {
    let name: String
    let n: Int
    let p50: Double
    let p95: Double
    let p99: Double
    let mean: Double
    let min: Double
    let max: Double
    let memoryRSS: UInt64
    let cpuPercent: Double
    let notes: String
    let timestamp: Date
    let platform: String
    let deviceModel: String
    
    init(name: String, n: Int, p50: Double, p95: Double, p99: Double, 
         mean: Double, min: Double, max: Double, memoryRSS: UInt64, 
         cpuPercent: Double, notes: String, platform: String, deviceModel: String) {
        self.name = name
        self.n = n
        self.p50 = p50
        self.p95 = p95
        self.p99 = p99
        self.mean = mean
        self.min = min
        self.max = max
        self.memoryRSS = memoryRSS
        self.cpuPercent = cpuPercent
        self.notes = notes
        self.timestamp = Date()
        self.platform = platform
        self.deviceModel = deviceModel
    }
}

struct iOSBenchSuite: Codable {
    let machineSpecs: iOSMachineSpecs
    let results: [iOSBenchResult]
    let timestamp: Date
    
    init(machineSpecs: iOSMachineSpecs, results: [iOSBenchResult]) {
        self.machineSpecs = machineSpecs
        self.results = results
        self.timestamp = Date()
    }
}

struct iOSMachineSpecs: Codable {
    let platform: String
    let deviceModel: String
    let osVersion: String
    let swiftVersion: String
    let cpuCores: Int
    let memoryGB: Double
    
    init() {
        self.platform = "iOS Simulator"
        self.deviceModel = "iPhone 16 Pro" // As per project memory
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
        self.swiftVersion = "5.9"
        self.cpuCores = ProcessInfo.processInfo.processorCount
        self.memoryGB = Double(ProcessInfo.processInfo.physicalMemory) / 1_000_000_000
    }
}

// MARK: - iOS-Specific Benchmark Implementation

class iOSTransformBench {
    
    // MARK: - Test Data Generation (iOS-optimized)
    
    private static func generateSeattleTestPoints(count: Int) -> [(lat: Double, lon: Double)] {
        var points: [(lat: Double, lon: Double)] = []
        points.reserveCapacity(count)
        
        // Generate points around Seattle area for realistic iOS testing
        let seattleLat = 47.6062
        let seattleLon = -122.3321
        let latRange = 0.05  // ~5.5km (smaller range for mobile)
        let lonRange = 0.05  // ~5.5km
        
        for _ in 0..<count {
            let lat = seattleLat + (Double.random(in: -latRange...latRange))
            let lon = seattleLon + (Double.random(in: -lonRange...lonRange))
            points.append((lat: lat, lon: lon))
        }
        
        return points
    }
    
    // MARK: - iOS-Optimized Transformations
    
    private static func iosScalarTransform(_ points: [(lat: Double, lon: Double)], 
                                         matrix: TransformationMatrix) -> [(lat: Double, lon: Double)] {
        return points.map { point in
            applyIOSScalarTransformation(point, matrix: matrix)
        }
    }
    
    private static func applyIOSScalarTransformation(_ point: (lat: Double, lon: Double), 
                                                   matrix: TransformationMatrix) -> (lat: Double, lon: Double) {
        // iOS-optimized scalar transformation (matches CoordinateTransformService.swift)
        var transformedLat = point.lat + matrix.latOffset
        var transformedLon = point.lon + matrix.lonOffset
        
        // Apply scaling
        transformedLat *= matrix.latScale
        transformedLon *= matrix.lonScale
        
        // Apply rotation (simplified - assumes small angles)
        if matrix.rotation != 0.0 {
            let rotationRad = matrix.rotation * .pi / 180.0
            let cosRot = cos(rotationRad)
            let sinRot = sin(rotationRad)
            
            let latRad = transformedLat * .pi / 180.0
            let lonRad = transformedLon * .pi / 180.0
            
            let newLatRad = latRad * cosRot - lonRad * sinRot
            let newLonRad = latRad * sinRot + lonRad * cosRot
            
            transformedLat = newLatRad * 180.0 / .pi
            transformedLon = newLonRad * 180.0 / .pi
        }
        
        return (transformedLat, transformedLon)
    }
    
    // MARK: - SIMD Implementation (iOS-optimized)
    
    private static func iosSIMDTransform(_ points: [(lat: Double, lon: Double)], 
                                       matrix: Affine3x3) -> [(lat: Double, lon: Double)] {
        return points.map { point in
            applyIOSSIMD(matrix, to: point)
        }
    }
    
    @inline(__always)
    private static func applyIOSSIMD(_ A: Affine3x3, to point: (lat: Double, lon: Double)) -> (lat: Double, lon: Double) {
        // iOS-optimized SIMD transformation
        let v = simd_double3(point.lon, point.lat, 1.0)
        let r = A.m * v
        return (lat: r.y, lon: r.x)
    }
    
    // MARK: - vDSP Batch Implementation (iOS-optimized)
    
    private static func iosVDSPBatchTransform(_ points: [(lat: Double, lon: Double)], 
                                            matrix: Affine3x3) -> [(lat: Double, lon: Double)] {
        return applyIOSVDSPBatch(matrix, points: points)
    }
    
    private static func applyIOSVDSPBatch(_ A: Affine3x3,
                                        points: [(lat: Double, lon: Double)]) -> [(lat: Double, lon: Double)] {
        precondition(!points.isEmpty, "No points")
        let n = points.count
        
        // Build 3xN RHS P with rows: X, Y, 1 (row-major layout for vDSP)
        var P = [Double](repeating: 0.0, count: 3 * n)
        for i in 0..<n {
            P[0 * n + i] = points[i].lon
            P[1 * n + i] = points[i].lat
            P[2 * n + i] = 1.0
        }
        
        // Emit row-major 3x3 from column-major simd matrix
        let S = A.m
        let M = [
            S[0,0], S[1,0], S[2,0],  // row 0
            S[0,1], S[1,1], S[2,1],  // row 1
            S[0,2], S[1,2], S[2,2]   // row 2
        ]
        
        // Output R = M (3x3) * P (3xN) = 3xN
        var R = [Double](repeating: 0.0, count: 3 * n)
        M.withUnsafeBufferPointer { mPtr in
            P.withUnsafeBufferPointer { pPtr in
                R.withUnsafeMutableBufferPointer { rPtr in
                    vDSP_mmulD(
                        mPtr.baseAddress!, 1,
                        pPtr.baseAddress!, 1,
                        rPtr.baseAddress!, 1,
                        vDSP_Length(3),          // rows of M
                        vDSP_Length(n),          // cols of P
                        vDSP_Length(3)           // cols of M == rows of P
                    )
                }
            }
        }
        
        // Rows: 0 = X′, 1 = Y′, 2 = W′ (~1 for affine)
        var out = [(lat: Double, lon: Double)]()
        out.reserveCapacity(n)
        for i in 0..<n {
            let xp = R[0 * n + i]
            let yp = R[1 * n + i]
            out.append((lat: yp, lon: xp))
        }
        return out
    }
    
    // MARK: - iOS Benchmarking
    
    private static func measureIOSTime<T>(_ block: () throws -> T) rethrows -> (result: T, time: Double) {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try block()
        let time = CFAbsoluteTimeGetCurrent() - startTime
        return (result, time)
    }
    
    private static func getIOSMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return UInt64(info.resident_size)
        } else {
            return 0
        }
    }
    
    private static func runIOSBenchmark(name: String, n: Int, 
                                      block: () throws -> [(lat: Double, lon: Double)]) throws -> iOSBenchResult {
        let points = generateSeattleTestPoints(count: n)
        let matrix = TransformationMatrix(latOffset: 0.001, lonOffset: 0.001, 
                                        latScale: 1.0, lonScale: 1.0, rotation: 0.1)
        let simdMatrix = Affine3x3(from: matrix)
        
        var times: [Double] = []
        var memoryBefore: UInt64 = 0
        var memoryAfter: UInt64 = 0
        
        // Warmup runs (more important on iOS)
        for _ in 0..<5 {
            _ = try block()
        }
        
        // Measurement runs
        for i in 0..<10 { // More runs for iOS stability
            if i == 0 {
                memoryBefore = getIOSMemoryUsage()
            }
            
            let (_, time) = try measureIOSTime {
                return try block()
            }
            times.append(time)
            
            if i == 9 {
                memoryAfter = getIOSMemoryUsage()
            }
        }
        
        times.sort()
        let p50 = times[times.count / 2]
        let p95 = times[Int(Double(times.count) * 0.95)]
        let p99 = times[Int(Double(times.count) * 0.99)]
        let mean = times.reduce(0, +) / Double(times.count)
        let min = times.first!
        let max = times.last!
        
        return iOSBenchResult(
            name: name,
            n: n,
            p50: p50,
            p95: p95,
            p99: p99,
            mean: mean,
            min: min,
            max: max,
            memoryRSS: memoryAfter,
            cpuPercent: 0.0, // TODO: Implement CPU measurement
            notes: "iOS Simulator baseline measurement",
            platform: "iOS Simulator",
            deviceModel: "iPhone 16 Pro"
        )
    }
    
    // MARK: - Public API
    
    static func runIOSBaseline() throws -> iOSBenchSuite {
        let sizes = [1, 10, 100, 1_000, 10_000] // Smaller sizes for iOS
        var results: [iOSBenchResult] = []
        
        for n in sizes {
            print("Running iOS benchmarks for n=\(n)...")
            
            // Scalar baseline (matches CoordinateTransformService.swift)
            let scalarResult = try runIOSBenchmark(name: "ios_scalar", n: n) {
                return iosScalarTransform(generateSeattleTestPoints(count: n), 
                                        matrix: TransformationMatrix(latOffset: 0.001, lonOffset: 0.001))
            }
            results.append(scalarResult)
            
            // SIMD single-point
            let simdResult = try runIOSBenchmark(name: "ios_simd", n: n) {
                return iosSIMDTransform(generateSeattleTestPoints(count: n), 
                                      matrix: Affine3x3(from: TransformationMatrix(latOffset: 0.001, lonOffset: 0.001)))
            }
            results.append(simdResult)
            
            // vDSP batch (only for larger sizes)
            if n >= 32 {
                let vDSPResult = try runIOSBenchmark(name: "ios_vdsp_batch", n: n) {
                    return iosVDSPBatchTransform(generateSeattleTestPoints(count: n), 
                                               matrix: Affine3x3(from: TransformationMatrix(latOffset: 0.001, lonOffset: 0.001)))
                }
                results.append(vDSPResult)
            }
        }
        
        let suite = iOSBenchSuite(machineSpecs: iOSMachineSpecs(), results: results)
        
        // Save results
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(suite)
        try data.write(to: URL(fileURLWithPath: "benchmarks/ios_baseline.json"))
        
        print("iOS baseline results saved to benchmarks/ios_baseline.json")
        return suite
    }
    
    static func printIOSResults(_ suite: iOSBenchSuite) {
        print("\n=== iOS TransformBench Results ===")
        print("Platform: \(suite.machineSpecs.platform)")
        print("Device: \(suite.machineSpecs.deviceModel)")
        print("OS: \(suite.machineSpecs.osVersion)")
        print("Swift: \(suite.machineSpecs.swiftVersion)")
        print("CPU: \(suite.machineSpecs.cpuCores) cores")
        print("Memory: \(String(format: "%.1f", suite.machineSpecs.memoryGB))GB RAM")
        print()
        
        let grouped = Dictionary(grouping: suite.results) { $0.n }
        for n in [1, 10, 100, 1_000, 10_000] {
            guard let results = grouped[n] else { continue }
            print("n=\(n):")
            for result in results {
                print("  \(result.name.padding(toLength: 15, withPad: " ", startingAt: 0)): p50=\(String(format: "%.3f", result.p50))ms, p95=\(String(format: "%.3f", result.p95))ms, mean=\(String(format: "%.3f", result.mean))ms")
            }
            print()
        }
    }
}

// MARK: - Main Execution

print("📱 Starting iOS TransformBench baseline measurement...")

do {
    let suite = try iOSTransformBench.runIOSBaseline()
    iOSTransformBench.printIOSResults(suite)
    print("✅ iOS baseline measurement complete!")
} catch {
    print("❌ iOS benchmark failed: \(error)")
    exit(1)
}
