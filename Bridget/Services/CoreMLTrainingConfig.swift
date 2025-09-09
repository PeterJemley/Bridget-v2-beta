// CoreMLTrainingConfig.swift
import Foundation

public struct CoreMLTrainingConfig: Codable, Sendable {
  public let modelType: ModelType
  public let modelURL: URL?
  public let inputShape: [Int]
  public let outputShape: [Int]
  public let epochs: Int
  public let learningRate: Double
  public let batchSize: Int
  public let shuffleSeed: UInt64?
  public let useANE: Bool
  public let earlyStoppingPatience: Int
  public let validationSplitRatio: Double
  public let outputKey: String

  public init(modelType: ModelType = .neuralNetwork,
              modelURL: URL? = nil,
              inputShape: [Int] = defaultInputShape,
              outputShape: [Int] = defaultOutputShape,
              epochs: Int = 100,
              learningRate: Double = 0.001,
              batchSize: Int = 32,
              shuffleSeed: UInt64? = 42,
              useANE: Bool = true,
              earlyStoppingPatience: Int = 10,
              validationSplitRatio: Double = 0.2,
              outputKey: String = "output")
  {
    self.modelType = modelType
    self.modelURL = modelURL
    self.inputShape = inputShape
    self.outputShape = outputShape
    self.epochs = epochs
    self.learningRate = learningRate
    self.batchSize = batchSize
    self.shuffleSeed = shuffleSeed
    self.useANE = useANE
    self.earlyStoppingPatience = earlyStoppingPatience
    self.validationSplitRatio = validationSplitRatio
    self.outputKey = outputKey
  }

  public static let validation = CoreMLTrainingConfig(modelType: .neuralNetwork,
                                                      epochs: 10,
                                                      learningRate: 0.01,
                                                      batchSize: 8,
                                                      useANE: false,
                                                      earlyStoppingPatience: 3,
                                                      validationSplitRatio: 0.3)
}

public enum ModelType: String, Codable, CaseIterable, Sendable {
  case neuralNetwork = "neural_network"
  case randomForest = "random_forest"
  case supportVectorMachine = "svm"

  public var displayName: String {
    switch self {
    case .neuralNetwork: return "Neural Network"
    case .randomForest: return "Random Forest"
    case .supportVectorMachine: return "Support Vector Machine"
    }
  }
}
