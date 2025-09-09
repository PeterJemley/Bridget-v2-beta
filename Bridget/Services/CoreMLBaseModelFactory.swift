// CoreMLBaseModelFactory.swift
import CoreML
import Foundation
import OSLog

public protocol CoreMLBaseModelFactoryProtocol {
  func createOrLoadBaseModel(configuration: MLModelConfiguration,
                             tempDirectory: URL?) async throws -> URL
  func createBaseModel(configuration: MLModelConfiguration,
                       in tempDirectory: URL?) async throws -> URL
}

public final class CoreMLBaseModelFactory: CoreMLBaseModelFactoryProtocol {
  private let logger = Logger(subsystem: "com.peterjemley.Bridget",
                              category: "CoreMLBaseModelFactory")

  public init() {}

  public func createOrLoadBaseModel(configuration: MLModelConfiguration,
                                    tempDirectory: URL?) async throws -> URL
  {
    // TODO: Avoid relying on KVC for "modelURL". Prefer a typed wrapper or explicit parameter
    //       to pass a base model URL into the training pipeline.
    // If caller provided a model URL in config, verify it can load
    if let existingURL = (configuration as AnyObject).value(
      forKey: "modelURL"
    ) as? URL {
      do {
        _ = try MLModel(contentsOf: existingURL,
                        configuration: configuration)
        logger.info("Using existing model from \(existingURL)")
        return existingURL
      } catch {
        logger.warning(
          "Failed to load existing model, creating new one: \(error.localizedDescription)"
        )
      }
    }

    // Otherwise, create a placeholder base model
    let baseModelURL = try await createBaseModel(configuration: configuration,
                                                 in: tempDirectory)
    logger.info("Created new base model for training at \(baseModelURL)")

    // TODO: When you have a real updatable .mlmodel file, compile it and return the compiled .mlmodelc directory:
    //       let compiledURL = try MLModel.compileModel(at: baseModelURL)
    //       return compiledURL
    // NOTE: The .mlmodelc URL is what MLUpdateTask(forModelAt:) expects for most updatable models.

    return baseModelURL
  }

  public func createBaseModel(configuration _: MLModelConfiguration,
                              in tempDirectory: URL?) async throws -> URL
  {
    // Choose directory: respect injected tempDirectory if provided; otherwise create a unique subdirectory
    let baseDir: URL
    if let tempDirectory {
      baseDir = tempDirectory
    } else {
      let uniqueDir = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
      try FileManager.default.createDirectory(at: uniqueDir,
                                              withIntermediateDirectories: true)
      baseDir = uniqueDir
    }

    let tempURL = baseDir.appendingPathComponent("base_model.mlmodel")

    // Ensure parent directory exists
    try FileManager.default.createDirectory(at: baseDir,
                                            withIntermediateDirectories: true)

    // TODO: Replace this placeholder file with a real updatable .mlmodel.
    //       The placeholder ensures current tests that expect training failure continue to pass.
    //       Once a real model exists, write it to tempURL (or copy from bundle), then compile via MLModel.compileModel(at:).
    // Create a simple placeholder model file
    let placeholderData = Data("placeholder".utf8)
    try placeholderData.write(to: tempURL)

    logger.info("Created placeholder base model at \(tempURL)")
    return tempURL
  }
}
