// CoreMLModelValidationResult.swift
import Foundation

public struct CoreMLModelValidationResult: Codable, Sendable {
  public let accuracy: Double
  public let loss: Double
  public let f1Score: Double
  public let precision: Double
  public let recall: Double
  public let confusionMatrix: [[Int]]
  public let lossTrend: [Double]
  public let validationAccuracy: Double
  public let validationLoss: Double
  public let isOverfitting: Bool
  public let hasConverged: Bool
  public let isValid: Bool
  public let inputShape: [Int]
  public let outputShape: [Int]

  public init(accuracy: Double,
              loss: Double,
              f1Score: Double,
              precision: Double,
              recall: Double,
              confusionMatrix: [[Int]],
              lossTrend: [Double] = [],
              validationAccuracy: Double = 0.0,
              validationLoss: Double = 0.0,
              isOverfitting: Bool = false,
              hasConverged: Bool = false,
              isValid: Bool = true,
              inputShape: [Int] = [],
              outputShape: [Int] = [])
  {
    self.accuracy = accuracy
    self.loss = loss
    self.f1Score = f1Score
    self.precision = precision
    self.recall = recall
    self.confusionMatrix = confusionMatrix
    self.lossTrend = lossTrend
    self.validationAccuracy = validationAccuracy
    self.validationLoss = validationLoss
    self.isOverfitting = isOverfitting
    self.hasConverged = hasConverged
    self.isValid = isValid
    self.inputShape = inputShape
    self.outputShape = outputShape
  }
}
