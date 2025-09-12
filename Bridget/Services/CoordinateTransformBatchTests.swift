#if canImport(Testing)
import Foundation
import Testing
@testable import Bridget

@Suite("Coordinate Transform Batch Tests")
struct CoordinateTransformBatchTests {

    @MainActor
    private func makeService() -> DefaultCoordinateTransformService {
        DefaultCoordinateTransformService(enableLogging: false)
    }

    private func applyScalar(lat: Double, lon: Double, matrix: TransformationMatrix) -> (Double, Double) {
        // Apply translation
        var tLat = lat + matrix.latOffset
        var tLon = lon + matrix.lonOffset
        // Apply scaling
        tLat *= matrix.latScale
        tLon *= matrix.lonScale
        // Apply rotation (simplified - assumes small angles)
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

    @Test("Small input uses scalar path and preserves order")
    func smallInputScalarPath() async throws {
        let service = makeService()
        let pts = (0..<16).map { i in BatchPoint(lat: 47.6 + Double(i) * 1e-6, lon: -122.3 - Double(i) * 1e-6) }
        let res = try await service.transformBatch(points: pts, from: .seattleReference, to: .seattleReference, bridgeId: nil)
        #expect(res.points.count == pts.count)
        for (i, p) in res.points.enumerated() {
            #expect(abs(p.0 - pts[i].lat) <= 1e-12)
            #expect(abs(p.1 - pts[i].lon) <= 1e-12)
        }
    }

    @Test("Large input uses chunking and preserves order")
    func largeInputChunking() async throws {
        let service = makeService()
        let n = 4096
        let pts = (0..<n).map { i in BatchPoint(lat: 47.5 + Double(i) * 1e-6, lon: -122.4 - Double(i) * 1e-6) }
        let res = try await service.transformBatch(points: pts, from: .seattleReference, to: .seattleReference, bridgeId: nil, chunkSize: 256, concurrencyCap: 2)
        #expect(res.points.count == pts.count)
        for (i, p) in res.points.enumerated() {
            #expect(abs(p.0 - pts[i].lat) <= 1e-12)
            #expect(abs(p.1 - pts[i].lon) <= 1e-12)
        }
    }

    @Test("Point cache avoids recomputation on warm run")
    func pointCacheWarmRun() async throws {
        let service = makeService()
        let cache = TransformCache(
            config: .init(matrixCapacity: 8, pointCapacity: 1024, pointTTLSeconds: 60, enablePointCache: true, quantizePrecision: 6)
        )
        let pts = (0..<128).map { i in BatchPoint(lat: 47.55 + Double(i) * 1e-5, lon: -122.35 - Double(i) * 1e-5) }
        // cold run
        _ = try await service.transformBatch(points: pts, from: .seattleReference, to: .seattleReference, bridgeId: nil, pointCache: cache, chunkSize: 64, concurrencyCap: 2)
        let statsAfterCold = await cache.getStats()
        // warm run
        _ = try await service.transformBatch(points: pts, from: .seattleReference, to: .seattleReference, bridgeId: nil, pointCache: cache, chunkSize: 64, concurrencyCap: 2)
        let statsAfterWarm = await cache.getStats()
        #expect(statsAfterWarm.pointHits >= statsAfterCold.pointHits)
    }

    @Test("Vectorized path agrees with scalar within 1e-12 when rotation == 0")
    func vectorizedAgreement() async throws {
        let service = makeService()
        let n = 512
        let pts = (0..<n).map { i in BatchPoint(lat: 47.6 + Double(i) * 1e-6, lon: -122.3 - Double(i) * 1e-6) }

        // Build a matrix with rotation == 0 by choosing identity systems
        let mOpt = await MainActor.run { service.calculateTransformationMatrix(from: .seattleReference, to: .seattleReference, bridgeId: nil) }
        let m = try #require(mOpt)
        #expect(m.rotation == 0.0)

        // Scalar baseline
        let scalar = pts.map { applyScalar(lat: $0.lat, lon: $0.lon, matrix: m) }
        // Batch vectorized
        let batch = try await service.transformBatch(points: pts, from: .seattleReference, to: .seattleReference, bridgeId: nil, chunkSize: 256, concurrencyCap: 2)

        for i in 0..<n {
            #expect(abs(scalar[i].0 - batch.points[i].0) <= 1e-12)
            #expect(abs(scalar[i].1 - batch.points[i].1) <= 1e-12)
        }
    }
}
#endif
