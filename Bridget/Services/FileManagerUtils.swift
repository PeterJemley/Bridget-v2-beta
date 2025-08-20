//
//  FileManagerUtils.swift
//  Bridget
//
//  ## Purpose
//  Centralized file system operations utility to eliminate duplication across services
//
//  ## Dependencies
//  Foundation framework, OSLog for logging
//
//  ## Integration Points
//  Used by CacheService, RetryRecoveryService, BridgeDataExporter, and various scripts
//  to provide consistent file operations with standardized error handling
//
//  ## Key Features
//  - Directory creation with existence checks
//  - Atomic file replacement operations
//  - File enumeration with filtering
//  - Cleanup operations with age-based filtering
//  - Consistent error handling and logging
//

import Foundation
import OSLog

// MARK: - Error Types

/// Errors that can occur during file operations
public enum FileManagerError: LocalizedError {
  case directoryCreationFailed(URL, Error)
  case fileReplacementFailed(URL, Error)
  case fileEnumerationFailed(URL, Error)
  case fileRemovalFailed(URL, Error)
  case fileAttributesFailed(URL, Error)
  case fileExistsCheckFailed(URL, Error)
  case invalidDirectory(URL)
  case fileNotFound(URL)
  case permissionDenied(URL)
  case diskFull(URL)
  
  public var errorDescription: String? {
    switch self {
    case let .directoryCreationFailed(url, error):
      return "Failed to create directory at \(url.path): \(error.localizedDescription)"
    case let .fileReplacementFailed(url, error):
      return "Failed to replace file at \(url.path): \(error.localizedDescription)"
    case let .fileEnumerationFailed(url, error):
      return "Failed to enumerate files in \(url.path): \(error.localizedDescription)"
    case let .fileRemovalFailed(url, error):
      return "Failed to remove file at \(url.path): \(error.localizedDescription)"
    case let .fileAttributesFailed(url, error):
      return "Failed to get attributes for \(url.path): \(error.localizedDescription)"
    case let .fileExistsCheckFailed(url, error):
      return "Failed to check existence of \(url.path): \(error.localizedDescription)"
    case let .invalidDirectory(url):
      return "Invalid directory path: \(url.path)"
    case let .fileNotFound(url):
      return "File not found: \(url.path)"
    case let .permissionDenied(url):
      return "Permission denied for \(url.path)"
    case let .diskFull(url):
      return "Disk full when writing to \(url.path)"
    }
  }
}

// MARK: - FileManagerUtils

/// Centralized utility for file system operations with consistent error handling
public struct FileManagerUtils {
  private static let logger = Logger(subsystem: "com.peterjemley.Bridget", category: "FileManagerUtils")
  private static let fileManager = FileManager.default
  
  // MARK: - Directory Operations
  
  /// Ensures a directory exists, creating it if necessary
  /// - Parameter url: The directory URL to ensure exists
  /// - Throws: `FileManagerError` if directory creation fails
  public static func ensureDirectoryExists(_ url: URL) throws {
    guard url.hasDirectoryPath else {
      throw FileManagerError.invalidDirectory(url)
    }
    
    do {
      if !fileManager.fileExists(atPath: url.path) {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        logger.info("Created directory: \(url.path)")
      }
    } catch {
      logger.error("Failed to create directory at \(url.path): \(error.localizedDescription)")
      throw FileManagerError.directoryCreationFailed(url, error)
    }
  }
  
  /// Creates a directory at the specified path, ensuring intermediate directories exist
  /// - Parameter path: The directory path to create
  /// - Throws: `FileManagerError` if directory creation fails
  public static func ensureDirectoryExists(at path: String) throws {
    let url = URL(fileURLWithPath: path)
    try ensureDirectoryExists(url)
  }
  
  // MARK: - File Replacement Operations
  
  /// Atomically replaces a file with a temporary file
  /// - Parameters:
  ///   - destination: The destination URL where the file should be placed
  ///   - temporary: The temporary file URL to replace with
  /// - Throws: `FileManagerError` if replacement fails
  public static func atomicReplaceItem(at destination: URL, with temporary: URL) throws {
    do {
      _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
      logger.info("Atomically replaced file at \(destination.path)")
    } catch {
      logger.error("Failed to replace file at \(destination.path): \(error.localizedDescription)")
      throw FileManagerError.fileReplacementFailed(destination, error)
    }
  }
  
  /// Creates a temporary file for atomic replacement operations
  /// - Parameters:
  ///   - directory: The directory where the temporary file should be created
  ///   - prefix: Optional prefix for the temporary file name
  ///   - extension: Optional file extension (without the dot)
  /// - Returns: The URL of the created temporary file
  /// - Throws: `FileManagerError` if file creation fails
  public static func createTemporaryFile(in directory: URL, prefix: String = "temp", extension: String? = nil) throws -> URL {
    let filename = "\(prefix)_\(UUID().uuidString)"
    let tempURL = directory.appendingPathComponent(filename)
    let finalURL = `extension` != nil ? tempURL.appendingPathExtension(`extension`!) : tempURL
    
    let created = fileManager.createFile(atPath: finalURL.path, contents: nil)
    if created {
      logger.debug("Created temporary file: \(finalURL.path)")
      return finalURL
    } else {
      logger.error("Failed to create temporary file at \(finalURL.path)")
      throw FileManagerError.fileReplacementFailed(finalURL, NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: nil))
    }
  }
  
  /// Creates a marker file (zero-byte file) for coordination purposes
  /// - Parameter url: The URL where the marker file should be created
  /// - Throws: `FileManagerError` if file creation fails
  public static func createMarkerFile(at url: URL) throws {
    let created = fileManager.createFile(atPath: url.path, contents: nil)
    if created {
      logger.debug("Created marker file: \(url.path)")
    } else {
      logger.error("Failed to create marker file at \(url.path)")
      throw FileManagerError.fileReplacementFailed(url, NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: nil))
    }
  }
  
  // MARK: - File Enumeration Operations
  
  /// Enumerates files in a directory with optional filtering
  /// - Parameters:
  ///   - directory: The directory to enumerate
  ///   - filter: Optional closure to filter files
  ///   - properties: Optional array of URL resource keys to fetch
  /// - Returns: Array of file URLs that match the filter
  /// - Throws: `FileManagerError` if enumeration fails
  public static func enumerateFiles(in directory: URL, 
                                   filter: ((URL) -> Bool)? = nil,
                                   properties: [URLResourceKey]? = nil) throws -> [URL] {
    do {
      let files = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: properties)
      let filteredFiles = filter != nil ? files.filter(filter!) : files
      logger.debug("Enumerated \(filteredFiles.count) files in \(directory.path)")
      return filteredFiles
    } catch {
      logger.error("Failed to enumerate files in \(directory.path): \(error.localizedDescription)")
      throw FileManagerError.fileEnumerationFailed(directory, error)
    }
  }
  
  /// Enumerates files in a directory by path string
  /// - Parameters:
  ///   - path: The directory path to enumerate
  ///   - filter: Optional closure to filter files
  ///   - properties: Optional array of URL resource keys to fetch
  /// - Returns: Array of file URLs that match the filter
  /// - Throws: `FileManagerError` if enumeration fails
  public static func enumerateFiles(at path: String,
                                   filter: ((URL) -> Bool)? = nil,
                                   properties: [URLResourceKey]? = nil) throws -> [URL] {
    let url = URL(fileURLWithPath: path)
    return try enumerateFiles(in: url, filter: filter, properties: properties)
  }
  
  // MARK: - File Removal Operations
  
  /// Removes a file at the specified URL
  /// - Parameter url: The URL of the file to remove
  /// - Throws: `FileManagerError` if removal fails
  public static func removeFile(at url: URL) throws {
    do {
      try fileManager.removeItem(at: url)
      logger.debug("Removed file: \(url.path)")
    } catch {
      logger.error("Failed to remove file at \(url.path): \(error.localizedDescription)")
      throw FileManagerError.fileRemovalFailed(url, error)
    }
  }
  
  /// Removes a file at the specified path
  /// - Parameter path: The path of the file to remove
  /// - Throws: `FileManagerError` if removal fails
  public static func removeFile(at path: String) throws {
    let url = URL(fileURLWithPath: path)
    try removeFile(at: url)
  }
  
  /// Removes old files based on creation date
  /// - Parameters:
  ///   - directory: The directory to search for old files
  ///   - olderThan: The cutoff date - files older than this will be removed
  ///   - filter: Optional closure to filter which files to consider for removal
  /// - Throws: `FileManagerError` if any operation fails
  public static func removeOldFiles(in directory: URL, 
                                   olderThan cutoffDate: Date,
                                   filter: ((URL) -> Bool)? = nil) throws {
    let files = try enumerateFiles(in: directory, 
                                  filter: filter,
                                  properties: [.creationDateKey])
    
    var removedCount = 0
    for file in files {
      do {
        let attributes = try fileManager.attributesOfItem(atPath: file.path)
        if let creationDate = attributes[.creationDate] as? Date,
           creationDate < cutoffDate {
          try removeFile(at: file)
          removedCount += 1
        }
      } catch {
        logger.warning("Failed to check attributes for \(file.path): \(error.localizedDescription)")
        // Continue with other files
      }
    }
    
    if removedCount > 0 {
      logger.info("Removed \(removedCount) old files from \(directory.path)")
    }
  }
  
  /// Removes files matching a specific pattern
  /// - Parameters:
  ///   - directory: The directory to search
  ///   - pattern: The pattern to match (e.g., "*.tmp", "temp_*")
  /// - Throws: `FileManagerError` if any operation fails
  public static func removeFilesMatchingPattern(in directory: URL, pattern: String) throws {
    let filter: (URL) -> Bool = { url in
      let filename = url.lastPathComponent
      return filename.range(of: pattern, options: .regularExpression) != nil
    }
    
    let files = try enumerateFiles(in: directory, filter: filter)
    for file in files {
      try removeFile(at: file)
    }
    
    if !files.isEmpty {
      logger.info("Removed \(files.count) files matching pattern '\(pattern)' from \(directory.path)")
    }
  }
  
  // MARK: - File Information Operations
  
  /// Checks if a file exists at the specified URL
  /// - Parameter url: The URL to check
  /// - Returns: `true` if the file exists, `false` otherwise
  public static func fileExists(at url: URL) -> Bool {
    return fileManager.fileExists(atPath: url.path)
  }
  
  /// Checks if a file exists at the specified path
  /// - Parameter path: The path to check
  /// - Returns: `true` if the file exists, `false` otherwise
  public static func fileExists(at path: String) -> Bool {
    let url = URL(fileURLWithPath: path)
    return fileExists(at: url)
  }
  
  /// Gets file attributes
  /// - Parameter url: The URL of the file
  /// - Returns: Dictionary of file attributes
  /// - Throws: `FileManagerError` if getting attributes fails
  public static func attributesOfItem(at url: URL) throws -> [FileAttributeKey: Any] {
    do {
      return try fileManager.attributesOfItem(atPath: url.path)
    } catch {
      logger.error("Failed to get attributes for \(url.path): \(error.localizedDescription)")
      throw FileManagerError.fileAttributesFailed(url, error)
    }
  }
  
  /// Gets file attributes by path
  /// - Parameter path: The path of the file
  /// - Returns: Dictionary of file attributes
  /// - Throws: `FileManagerError` if getting attributes fails
  public static func attributesOfItem(at path: String) throws -> [FileAttributeKey: Any] {
    let url = URL(fileURLWithPath: path)
    return try attributesOfItem(at: url)
  }
  
  // MARK: - Utility Operations
  
  /// Calculates the total size of all files in a directory
  /// - Parameters:
  ///   - directory: The directory to calculate size for
  ///   - filter: Optional closure to filter which files to include
  /// - Returns: Total size in bytes
  /// - Throws: `FileManagerError` if any operation fails
  public static func calculateDirectorySize(in directory: URL, filter: ((URL) -> Bool)? = nil) throws -> Int64 {
    let files = try enumerateFiles(in: directory, filter: filter, properties: [.fileSizeKey])
    
    var totalSize: Int64 = 0
    for file in files {
      do {
        let attributes = try attributesOfItem(at: file)
        totalSize += attributes[.size] as? Int64 ?? 0
      } catch {
        logger.warning("Failed to get size for \(file.path): \(error.localizedDescription)")
        // Continue with other files
      }
    }
    
    return totalSize
  }
  
  /// Gets the system documents directory URL
  /// - Returns: The documents directory URL
  /// - Throws: `FileManagerError` if the directory is not accessible
  public static func documentsDirectory() throws -> URL {
    guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
      throw FileManagerError.invalidDirectory(URL(fileURLWithPath: "Documents"))
    }
    return documentsPath
  }
  
  /// Gets the system downloads directory URL (macOS only)
  /// - Returns: The downloads directory URL, or nil if not available
  public static func downloadsDirectory() -> URL? {
    #if os(macOS)
    return fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first
    #else
    return nil
    #endif
  }
  
  /// Gets the system temporary directory URL
  /// - Returns: The temporary directory URL
  public static func temporaryDirectory() -> URL {
    return fileManager.temporaryDirectory
  }
}

