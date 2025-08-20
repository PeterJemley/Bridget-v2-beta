//
//  FileManagerUtilsTests.swift
//  BridgetTests
//
//  ## Purpose
//  Comprehensive tests for FileManagerUtils to ensure consistent file operations
//
//  ## Dependencies
//  Testing framework, Foundation, FileManagerUtils
//
//  ## Test Coverage
//  - Directory operations (creation, existence checks)
//  - File operations (creation, replacement, removal)
//  - File enumeration and filtering
//  - Error handling and edge cases
//

import Foundation
import Testing

@testable import Bridget

/// Test suite for FileManagerUtils to ensure consistent file operations across the app
@Suite("FileManagerUtils Tests")
struct FileManagerUtilsTests {
  
  // MARK: - Test Setup
  
  private let testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("FileManagerUtilsTests")
  
  @Test("setup and teardown test directory")
  func setupTestDirectory() async throws {
    // Clean up any existing test directory
    try? FileManagerUtils.removeFile(at: testDirectory)
    
    // Create fresh test directory
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    // Verify it exists
    #expect(try FileManagerUtils.fileExists(at: testDirectory))
    
    // Clean up
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  // MARK: - Directory Operations Tests
  
  @Test("ensureDirectoryExists creates directory when it doesn't exist")
  func ensureDirectoryExistsCreatesDirectory() async throws {
    let newDir = testDirectory.appendingPathComponent("new_directory")
    
    // Ensure directory doesn't exist
    try? FileManagerUtils.removeFile(at: newDir)
    
    // Create directory
    try FileManagerUtils.ensureDirectoryExists(newDir)
    
    // Verify it exists
    #expect(try FileManagerUtils.fileExists(at: newDir))
    
    // Clean up
    try FileManagerUtils.removeFile(at: newDir)
  }
  
  @Test("ensureDirectoryExists doesn't fail when directory already exists")
  func ensureDirectoryExistsWithExistingDirectory() async throws {
    let existingDir = testDirectory.appendingPathComponent("existing_directory")
    
    // Create directory first
    try FileManagerUtils.ensureDirectoryExists(existingDir)
    
    // Try to create it again
    try FileManagerUtils.ensureDirectoryExists(existingDir)
    
    // Verify it still exists
    #expect(try FileManagerUtils.fileExists(at: existingDir))
    
    // Clean up
    try FileManagerUtils.removeFile(at: existingDir)
  }
  
  @Test("ensureDirectoryExists throws error for invalid directory path")
  func ensureDirectoryExistsWithInvalidPath() async throws {
    let invalidURL = URL(string: "not-a-file-url")!
    
    do {
      try FileManagerUtils.ensureDirectoryExists(invalidURL)
      throw TestError.unexpectedSuccess("Should have thrown error for invalid URL")
    } catch let error as FileManagerError {
      #expect(error == .invalidDirectory(invalidURL))
    }
  }
  
  // MARK: - File Operations Tests
  
  @Test("createTemporaryFile creates file with correct extension")
  func createTemporaryFileWithExtension() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let tempFile = try FileManagerUtils.createTemporaryFile(in: testDirectory, 
                                                           prefix: "test", 
                                                           extension: "txt")
    
    // Verify file exists
    #expect(try FileManagerUtils.fileExists(at: tempFile))
    
    // Verify extension
    #expect(tempFile.pathExtension == "txt")
    
    // Verify prefix
    #expect(tempFile.lastPathComponent.hasPrefix("test_"))
    
    // Clean up
    try FileManagerUtils.removeFile(at: tempFile)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  @Test("createMarkerFile creates zero-byte file")
  func createMarkerFileCreatesZeroByteFile() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let markerFile = testDirectory.appendingPathComponent("test.done")
    try FileManagerUtils.createMarkerFile(at: markerFile)
    
    // Verify file exists
    #expect(try FileManagerUtils.fileExists(at: markerFile))
    
    // Verify it's zero bytes
    let attributes = try FileManagerUtils.attributesOfItem(at: markerFile)
    let fileSize = attributes[.size] as? Int64 ?? -1
    #expect(fileSize == 0)
    
    // Clean up
    try FileManagerUtils.removeFile(at: markerFile)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  @Test("atomicReplaceItem replaces file atomically")
  func atomicReplaceItemReplacesFile() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let originalFile = testDirectory.appendingPathComponent("original.txt")
    let tempFile = testDirectory.appendingPathComponent("temp.txt")
    
    // Create original file with content
    try "original content".write(to: originalFile, atomically: true, encoding: .utf8)
    
    // Create temp file with new content
    try "new content".write(to: tempFile, atomically: true, encoding: .utf8)
    
    // Perform atomic replacement
    try FileManagerUtils.atomicReplaceItem(at: originalFile, with: tempFile)
    
    // Verify original file has new content
    let content = try String(contentsOf: originalFile)
    #expect(content == "new content")
    
    // Verify temp file is gone
    #expect(!try FileManagerUtils.fileExists(at: tempFile))
    
    // Clean up
    try FileManagerUtils.removeFile(at: originalFile)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  // MARK: - File Enumeration Tests
  
  @Test("enumerateFiles returns all files in directory")
  func enumerateFilesReturnsAllFiles() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    // Create test files
    let file1 = testDirectory.appendingPathComponent("file1.txt")
    let file2 = testDirectory.appendingPathComponent("file2.txt")
    let file3 = testDirectory.appendingPathComponent("file3.dat")
    
    try "content1".write(to: file1, atomically: true, encoding: .utf8)
    try "content2".write(to: file2, atomically: true, encoding: .utf8)
    try "content3".write(to: file3, atomically: true, encoding: .utf8)
    
    // Enumerate all files
    let files = try FileManagerUtils.enumerateFiles(in: testDirectory)
    
    // Should find 3 files
    #expect(files.count == 3)
    #expect(files.contains(file1))
    #expect(files.contains(file2))
    #expect(files.contains(file3))
    
    // Clean up
    try FileManagerUtils.removeFile(at: file1)
    try FileManagerUtils.removeFile(at: file2)
    try FileManagerUtils.removeFile(at: file3)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  @Test("enumerateFiles with filter returns only matching files")
  func enumerateFilesWithFilter() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    // Create test files
    let file1 = testDirectory.appendingPathComponent("file1.txt")
    let file2 = testDirectory.appendingPathComponent("file2.txt")
    let file3 = testDirectory.appendingPathComponent("file3.dat")
    
    try "content1".write(to: file1, atomically: true, encoding: .utf8)
    try "content2".write(to: file2, atomically: true, encoding: .utf8)
    try "content3".write(to: file3, atomically: true, encoding: .utf8)
    
    // Enumerate only .txt files
    let txtFiles = try FileManagerUtils.enumerateFiles(in: testDirectory) { url in
      url.pathExtension == "txt"
    }
    
    // Should find 2 .txt files
    #expect(txtFiles.count == 2)
    #expect(txtFiles.contains(file1))
    #expect(txtFiles.contains(file2))
    #expect(!txtFiles.contains(file3))
    
    // Clean up
    try FileManagerUtils.removeFile(at: file1)
    try FileManagerUtils.removeFile(at: file2)
    try FileManagerUtils.removeFile(at: file3)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  // MARK: - File Removal Tests
  
  @Test("removeFile removes existing file")
  func removeFileRemovesExistingFile() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let testFile = testDirectory.appendingPathComponent("test.txt")
    try "test content".write(to: testFile, atomically: true, encoding: .utf8)
    
    // Verify file exists
    #expect(try FileManagerUtils.fileExists(at: testFile))
    
    // Remove file
    try FileManagerUtils.removeFile(at: testFile)
    
    // Verify file is gone
    #expect(!try FileManagerUtils.fileExists(at: testFile))
    
    // Clean up
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  @Test("removeFile throws error for non-existent file")
  func removeFileThrowsErrorForNonExistentFile() async throws {
    let nonExistentFile = testDirectory.appendingPathComponent("nonexistent.txt")
    
    do {
      try FileManagerUtils.removeFile(at: nonExistentFile)
      throw TestError.unexpectedSuccess("Should have thrown error for non-existent file")
    } catch {
      // Expected error
      #expect(error is FileManagerError)
    }
  }
  
  @Test("removeOldFiles removes files older than cutoff date")
  func removeOldFilesRemovesOldFiles() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let oldFile = testDirectory.appendingPathComponent("old.txt")
    let newFile = testDirectory.appendingPathComponent("new.txt")
    
    // Create files
    try "old content".write(to: oldFile, atomically: true, encoding: .utf8)
    try "new content".write(to: newFile, atomically: true, encoding: .utf8)
    
    // Set old file modification date to 2 days ago
    let oldDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
    try FileManager.default.setAttributes([.modificationDate: oldDate], ofItemAtPath: oldFile.path)
    
    // Remove files older than 1 day
    let cutoffDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    try FileManagerUtils.removeOldFiles(in: testDirectory, olderThan: cutoffDate)
    
    // Verify old file is gone, new file remains
    #expect(!try FileManagerUtils.fileExists(at: oldFile))
    #expect(try FileManagerUtils.fileExists(at: newFile))
    
    // Clean up
    try FileManagerUtils.removeFile(at: newFile)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  // MARK: - File Information Tests
  
  @Test("fileExists returns correct boolean values")
  func fileExistsReturnsCorrectValues() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let existingFile = testDirectory.appendingPathComponent("exists.txt")
    let nonExistentFile = testDirectory.appendingPathComponent("doesnt_exist.txt")
    
    // Create a file
    try "content".write(to: existingFile, atomically: true, encoding: .utf8)
    
    // Test existing file
    #expect(try FileManagerUtils.fileExists(at: existingFile))
    
    // Test non-existent file
    #expect(!try FileManagerUtils.fileExists(at: nonExistentFile))
    
    // Clean up
    try FileManagerUtils.removeFile(at: existingFile)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  @Test("attributesOfItem returns file attributes")
  func attributesOfItemReturnsAttributes() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let testFile = testDirectory.appendingPathComponent("attributes.txt")
    let content = "test content for attributes"
    try content.write(to: testFile, atomically: true, encoding: .utf8)
    
    let attributes = try FileManagerUtils.attributesOfItem(at: testFile)
    
    // Verify size attribute
    let fileSize = attributes[.size] as? Int64 ?? -1
    #expect(fileSize == Int64(content.utf8.count))
    
    // Verify modification date exists
    let modDate = attributes[.modificationDate] as? Date
    #expect(modDate != nil)
    
    // Clean up
    try FileManagerUtils.removeFile(at: testFile)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  // MARK: - Utility Tests
  
  @Test("calculateDirectorySize returns correct total size")
  func calculateDirectorySizeReturnsCorrectSize() async throws {
    try FileManagerUtils.ensureDirectoryExists(testDirectory)
    
    let file1 = testDirectory.appendingPathComponent("file1.txt")
    let file2 = testDirectory.appendingPathComponent("file2.txt")
    
    let content1 = "content1"
    let content2 = "content2"
    
    try content1.write(to: file1, atomically: true, encoding: .utf8)
    try content2.write(to: file2, atomically: true, encoding: .utf8)
    
    let totalSize = try FileManagerUtils.calculateDirectorySize(in: testDirectory)
    let expectedSize = Int64(content1.utf8.count + content2.utf8.count)
    
    #expect(totalSize == expectedSize)
    
    // Clean up
    try FileManagerUtils.removeFile(at: file1)
    try FileManagerUtils.removeFile(at: file2)
    try FileManagerUtils.removeFile(at: testDirectory)
  }
  
  @Test("documentsDirectory returns valid URL")
  func documentsDirectoryReturnsValidURL() async throws {
    let documentsURL = try FileManagerUtils.documentsDirectory()
    
    // Verify it's a valid URL
    #expect(documentsURL.hasDirectoryPath)
    
    // Verify it exists
    #expect(try FileManagerUtils.fileExists(at: documentsURL))
  }
  
  @Test("temporaryDirectory returns valid URL")
  func temporaryDirectoryReturnsValidURL() async throws {
    let tempURL = FileManagerUtils.temporaryDirectory()
    
    // Verify it's a valid URL
    #expect(tempURL.hasDirectoryPath)
    
    // Verify it exists
    #expect(try FileManagerUtils.fileExists(at: tempURL))
  }
  
  // MARK: - Error Handling Tests
  
  @Test("operations throw appropriate FileManagerError types")
  func operationsThrowAppropriateErrors() async throws {
    // Test directory creation with invalid URL
    let invalidURL = URL(string: "not-a-file-url")!
    
    do {
      try FileManagerUtils.ensureDirectoryExists(invalidURL)
      throw TestError.unexpectedSuccess("Should have thrown error for invalid URL")
    } catch let error as FileManagerError {
      #expect(error == .invalidDirectory(invalidURL))
    }
    
    // Test file removal of non-existent file
    let nonExistentFile = testDirectory.appendingPathComponent("nonexistent.txt")
    
    do {
      try FileManagerUtils.removeFile(at: nonExistentFile)
      throw TestError.unexpectedSuccess("Should have thrown error for non-existent file")
    } catch let error as FileManagerError {
      #expect(error == .fileRemovalFailed(nonExistentFile, error))
    }
  }
}

// MARK: - Test Error Type

private enum TestError: Error {
  case unexpectedSuccess(String)
}

