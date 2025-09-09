//
//  CoreMLSyntheticDataFactory.swift
//  Bridget
//
//  Generates deterministic synthetic FeatureVector data for tests and debugging.
//

import Foundation

#if DEBUG
  public extension CoreMLSyntheticDataFactory {
    static func generateSyntheticData(count: Int) -> [FeatureVector] {
      return generate(count: count)
    }
  }
#endif
