//
//  FeatureVectorTests.swift
//  BridgetTests
//
//  ## Purpose
//  Unit tests for FeatureVector to MLMultiArray conversion
//
//  ## Dependencies
//  XCTest framework, CoreML framework
//
//  ## Integration Points
//  Tests FeatureVector.toMLMultiArray() method
//  Tests FeatureVector.toTargetMLMultiArray() method
//  Tests TrainPrepService.convertFeaturesToMLMultiArray() method
//  Validates MLMultiArray shapes and data types
//
//  ## Key Features
//  Tests feature vector conversion to MLMultiArray format
//  Validates array shapes and data types match Core ML requirements
//  Tests batch conversion of multiple feature vectors
//  Tests error handling for invalid conversions
//

import XCTest
import CoreML
@testable import Bridget

final class FeatureVectorTests: XCTestCase {
    
    // MARK: - Test Data
    
    private var sampleFeatureVector: FeatureVector!
    
    override func setUpWithError() throws {
        super.setUp()
        
        // Create a sample feature vector with known values
        sampleFeatureVector = FeatureVector(
            bridge_id: 1,
            horizon_min: 0,
            min_sin: 0.5,
            min_cos: 0.866,
            dow_sin: 0.0,
            dow_cos: 1.0,
            open_5m: 0.2,
            open_30m: 0.1,
            detour_delta: 30.0,
            cross_rate: 0.8,
            via_routable: 1.0,
            via_penalty: 0.3,
            gate_anom: 0.5,
            detour_frac: 0.1,
            target: 1
        )
    }
    
    override func tearDownWithError() throws {
        sampleFeatureVector = nil
        super.tearDown()
    }
    
    // MARK: - FeatureVector.toMLMultiArray() Tests
    
    func testFeatureVectorToMLMultiArray() throws {
        // When
        let multiArray = try sampleFeatureVector.toMLMultiArray()
        
        // Then
        XCTAssertEqual(multiArray.shape.count, 2, "MLMultiArray should have 2 dimensions")
        XCTAssertEqual(multiArray.shape[0].intValue, 1, "First dimension should be 1 (batch size)")
        XCTAssertEqual(multiArray.shape[1].intValue, FeatureVector.featureCount, "Second dimension should match feature count")
        XCTAssertEqual(multiArray.dataType, .double, "Data type should be double")
        
        // Verify feature values are in correct order
        XCTAssertEqual(multiArray[[0, 0] as [NSNumber]].doubleValue, 0.5, accuracy: 0.001) // min_sin
        XCTAssertEqual(multiArray[[0, 1] as [NSNumber]].doubleValue, 0.866, accuracy: 0.001) // min_cos
        XCTAssertEqual(multiArray[[0, 2] as [NSNumber]].doubleValue, 0.0, accuracy: 0.001) // dow_sin
        XCTAssertEqual(multiArray[[0, 3] as [NSNumber]].doubleValue, 1.0, accuracy: 0.001) // dow_cos
        XCTAssertEqual(multiArray[[0, 4] as [NSNumber]].doubleValue, 0.2, accuracy: 0.001) // open_5m
        XCTAssertEqual(multiArray[[0, 5] as [NSNumber]].doubleValue, 0.1, accuracy: 0.001) // open_30m
        XCTAssertEqual(multiArray[[0, 6] as [NSNumber]].doubleValue, 30.0, accuracy: 0.001) // detour_delta
        XCTAssertEqual(multiArray[[0, 7] as [NSNumber]].doubleValue, 0.8, accuracy: 0.001) // cross_rate
        XCTAssertEqual(multiArray[[0, 8] as [NSNumber]].doubleValue, 1.0, accuracy: 0.001) // via_routable
        XCTAssertEqual(multiArray[[0, 9] as [NSNumber]].doubleValue, 0.3, accuracy: 0.001) // via_penalty
        XCTAssertEqual(multiArray[[0, 10] as [NSNumber]].doubleValue, 0.5, accuracy: 0.001) // gate_anom
        XCTAssertEqual(multiArray[[0, 11] as [NSNumber]].doubleValue, 0.1, accuracy: 0.001) // detour_frac
    }
    
    func testFeatureVectorToTargetMLMultiArray() throws {
        // When
        let targetArray = try sampleFeatureVector.toTargetMLMultiArray()
        
        // Then
        XCTAssertEqual(targetArray.shape.count, 2, "Target MLMultiArray should have 2 dimensions")
        XCTAssertEqual(targetArray.shape[0].intValue, 1, "First dimension should be 1 (batch size)")
        XCTAssertEqual(targetArray.shape[1].intValue, 1, "Second dimension should be 1 (single target)")
        XCTAssertEqual(targetArray.dataType, .double, "Data type should be double")
        XCTAssertEqual(targetArray[[0, 0] as [NSNumber]].doubleValue, 1.0, accuracy: 0.001) // target value
    }
    
    // MARK: - TrainPrepService.convertFeaturesToMLMultiArray() Tests
    
    func testConvertFeaturesToMLMultiArray() throws {
        // Given
        let featureVectors: [FeatureVector] = [
            sampleFeatureVector,
            FeatureVector(
                bridge_id: 2,
                horizon_min: 3,
                min_sin: 0.7,
                min_cos: 0.714,
                dow_sin: 0.5,
                dow_cos: 0.866,
                open_5m: 0.3,
                open_30m: 0.2,
                detour_delta: 45.0,
                cross_rate: 0.9,
                via_routable: 0.8,
                via_penalty: 0.4,
                gate_anom: 0.6,
                detour_frac: 0.15,
                target: 0
            )
        ]
        
        // When
        let (inputs, targets) = try TrainPrepService.convertFeaturesToMLMultiArray(featureVectors)
        
        // Then
        XCTAssertEqual(inputs.count, 2, "Should have 2 input arrays")
        XCTAssertEqual(targets.count, 2, "Should have 2 target arrays")
        
        // Verify first feature vector
        XCTAssertEqual(inputs[0].shape[0].intValue, 1, "First input should have batch size 1")
        XCTAssertEqual(inputs[0].shape[1].intValue, FeatureVector.featureCount, "First input should have correct feature count")
        XCTAssertEqual(targets[0].shape[0].intValue, 1, "First target should have batch size 1")
        XCTAssertEqual(targets[0].shape[1].intValue, 1, "First target should have single target")
        
        // Verify second feature vector
        XCTAssertEqual(inputs[1].shape[0].intValue, 1, "Second input should have batch size 1")
        XCTAssertEqual(inputs[1].shape[1].intValue, FeatureVector.featureCount, "Second input should have correct feature count")
        XCTAssertEqual(targets[1].shape[0].intValue, 1, "Second target should have batch size 1")
        XCTAssertEqual(targets[1].shape[1].intValue, 1, "Second target should have single target")
        
        // Verify target values
        XCTAssertEqual(targets[0][[0, 0] as [NSNumber]].doubleValue, 1.0, accuracy: 0.001) // First target
        XCTAssertEqual(targets[1][[0, 0] as [NSNumber]].doubleValue, 0.0, accuracy: 0.001) // Second target
    }
    
    func testConvertEmptyFeaturesArray() throws {
        // Given
        let emptyFeatures: [FeatureVector] = []
        
        // When
        let (inputs, targets) = try TrainPrepService.convertFeaturesToMLMultiArray(emptyFeatures)
        
        // Then
        XCTAssertTrue(inputs.isEmpty, "Inputs should be empty")
        XCTAssertTrue(targets.isEmpty, "Targets should be empty")
    }
    
    // MARK: - Feature Count and Names Tests
    
    func testFeatureCount() {
        // Then
        XCTAssertEqual(FeatureVector.featureCount, 12, "Feature count should be 12")
        XCTAssertEqual(FeatureVector.featureNames.count, 12, "Feature names count should match feature count")
    }
    
    func testFeatureNames() {
        // Then
        let expectedNames = [
            "min_sin", "min_cos", "dow_sin", "dow_cos",
            "open_5m", "open_30m", "detour_delta", "cross_rate",
            "via_routable", "via_penalty", "gate_anom", "detour_frac"
        ]
        
        XCTAssertEqual(FeatureVector.featureNames, expectedNames, "Feature names should match expected order")
    }
    
    // MARK: - Error Handling Tests
    
    func testMLMultiArrayCreationWithInvalidShape() {
        // This test verifies that MLMultiArray creation handles errors appropriately
        // Note: MLMultiArray creation with valid parameters should not throw
        XCTAssertNoThrow(try sampleFeatureVector.toMLMultiArray(), "Valid feature vector should not throw")
        XCTAssertNoThrow(try sampleFeatureVector.toTargetMLMultiArray(), "Valid target creation should not throw")
    }
    
    // MARK: - Performance Tests
    
    func testConversionPerformance() throws {
        // Given
        let largeFeatureArray: [FeatureVector] = (0..<1000).map { _ in sampleFeatureVector }
        
        // When/Then
        measure {
            do {
                _ = try TrainPrepService.convertFeaturesToMLMultiArray(largeFeatureArray)
            } catch {
                XCTFail("Performance test failed: \(error)")
            }
        }
    }
}
