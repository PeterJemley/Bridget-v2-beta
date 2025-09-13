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

    /// Creates a unique test directory for each test to avoid interference
    private func createUniqueTestDirectory() throws -> URL {
        let testDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerUtilsTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        // Ensure the directory is clean
        try? FileManagerUtils.removeFile(at: testDir)

        return testDir
    }

    /// Cleans up test directory after each test
    private func cleanupTestDirectory(_ url: URL) {
        try? FileManagerUtils.removeFile(at: url)
    }

    // MARK: - Test Error Type

    /// Custom error type for testing
    struct TestError: LocalizedError {
        let description: String

        var errorDescription: String? {
            return description
        }

        static func unexpectedSuccess(_ message: String) -> TestError {
            return TestError(description: "Unexpected success: \(message)")
        }
    }

    // MARK: - Preflight Tests

    @Test("Environment preflight check - verify writable directories")
    func environmentPreflightCheck() throws {
        // Check temporary directory
        let tempDir = FileManager.default.temporaryDirectory
        print("📁 Temporary directory: \(tempDir.path)")
        #expect(FileManager.default.fileExists(atPath: tempDir.path))
        #expect(FileManager.default.isWritableFile(atPath: tempDir.path))

        // Check documents directory
        let documentsDir = try FileManagerUtils.documentsDirectory()
        print("📁 Documents directory: \(documentsDir.path)")
        #expect(FileManager.default.fileExists(atPath: documentsDir.path))
        #expect(FileManager.default.isWritableFile(atPath: documentsDir.path))

        // Test creating a unique test directory
        let testDir =
            tempDir
            .appendingPathComponent("FileManagerUtilsTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)

        print("📁 Test directory: \(testDir.path)")
        try FileManagerUtils.ensureDirectoryExists(testDir)
        #expect(FileManager.default.fileExists(atPath: testDir.path))

        // Clean up
        try? FileManagerUtils.removeFile(at: testDir)
        print("✅ Environment preflight check passed")
    }

    // MARK: - Directory Tests

    @Test("Documents directory returns valid URL")
    func documentsDirectoryReturnsValidURL() throws {
        let documentsURL = try FileManagerUtils.documentsDirectory()
        #expect(documentsURL.isFileURL)
        #expect(FileManager.default.fileExists(atPath: documentsURL.path))
    }

    @Test("Temporary directory returns valid URL")
    func temporaryDirectoryReturnsValidURL() throws {
        let tempURL = FileManagerUtils.temporaryDirectory()
        #expect(tempURL.isFileURL)
        #expect(FileManager.default.fileExists(atPath: tempURL.path))
    }

    @Test("Ensure directory exists creates directory")
    func ensureDirectoryExistsCreatesDirectory() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        try FileManagerUtils.ensureDirectoryExists(testDir)
        #expect(FileManager.default.fileExists(atPath: testDir.path))
        var isDirectory: ObjCBool = false
        #expect(
            FileManager.default.fileExists(
                atPath: testDir.path,
                isDirectory: &isDirectory
            )
        )
        #expect(isDirectory.boolValue)
    }

    @Test("Ensure directory exists with existing directory")
    func ensureDirectoryExistsWithExistingDirectory() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        // Create directory first
        try FileManager.default.createDirectory(
            at: testDir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Should not throw when directory already exists
        try FileManagerUtils.ensureDirectoryExists(testDir)
        #expect(FileManager.default.fileExists(atPath: testDir.path))
    }

    @Test("Ensure directory exists with invalid path")
    func ensureDirectoryExistsWithInvalidPath() throws {
        let invalidPath = URL(
            fileURLWithPath: "/invalid/path/that/should/not/exist"
        )

        do {
            try FileManagerUtils.ensureDirectoryExists(invalidPath)
            throw TestError.unexpectedSuccess(
                "Should have thrown an error for invalid path"
            )
        } catch {
            // Expected to throw an error
            #expect(error is FileManagerError)
        }
    }

    // MARK: - File Tests

    @Test("File exists returns correct values")
    func fileExistsReturnsCorrectValues() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let testFile = testDir.appendingPathComponent("test.txt")

        // File should not exist initially
        #expect(!FileManagerUtils.fileExists(at: testFile))

        // Create the file
        try "test content".write(
            to: testFile,
            atomically: true,
            encoding: .utf8
        )

        // File should exist now
        #expect(FileManagerUtils.fileExists(at: testFile))
    }

    @Test("Create marker file creates zero byte file")
    func createMarkerFileCreatesZeroByteFile() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let markerFile = testDir.appendingPathComponent(".marker")
        try FileManagerUtils.createMarkerFile(at: markerFile)

        #expect(FileManagerUtils.fileExists(at: markerFile))

        let attributes = try FileManager.default.attributesOfItem(
            atPath: markerFile.path
        )
        let fileSize = attributes[.size] as? Int64 ?? 0
        #expect(fileSize == 0)
    }

    @Test("Remove file removes existing file")
    func removeFileRemovesExistingFile() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let testFile = testDir.appendingPathComponent("test.txt")
        try "test content".write(
            to: testFile,
            atomically: true,
            encoding: .utf8
        )

        #expect(FileManagerUtils.fileExists(at: testFile))

        try FileManagerUtils.removeFile(at: testFile)
        #expect(!FileManagerUtils.fileExists(at: testFile))
    }

    @Test("Remove file throws error for non-existent file")
    func removeFileThrowsErrorForNonExistentFile() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let nonExistentFile = testDir.appendingPathComponent("nonexistent.txt")

        do {
            try FileManagerUtils.removeFile(at: nonExistentFile)
            throw TestError.unexpectedSuccess(
                "Should have thrown an error for non-existent file"
            )
        } catch {
            #expect(error is FileManagerError)
        }
    }

    @Test("Atomic replace item replaces file")
    func atomicReplaceItemReplacesFile() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let originalFile = testDir.appendingPathComponent("original.txt")
        let newFile = testDir.appendingPathComponent("new.txt")

        try "original content".write(
            to: originalFile,
            atomically: true,
            encoding: .utf8
        )
        try "new content".write(to: newFile, atomically: true, encoding: .utf8)

        try FileManagerUtils.atomicReplaceItem(at: originalFile, with: newFile)

        #expect(FileManagerUtils.fileExists(at: originalFile))
        #expect(!FileManagerUtils.fileExists(at: newFile))

        let content = try String(contentsOf: originalFile, encoding: .utf8)
        #expect(content == "new content")
    }

    @Test("Create temporary file with extension")
    func createTemporaryFileWithExtension() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let tempFile = try FileManagerUtils.createTemporaryFile(
            in: testDir,
            prefix: "test",
            extension: "tmp"
        )

        #expect(FileManagerUtils.fileExists(at: tempFile))
        #expect(tempFile.pathExtension == "tmp")
        #expect(tempFile.deletingLastPathComponent() == testDir)
    }

    // MARK: - File Enumeration Tests

    @Test("Enumerate files returns all files")
    func enumerateFilesReturnsAllFiles() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let file1 = testDir.appendingPathComponent("file1.txt")
        let file2 = testDir.appendingPathComponent("file2.txt")
        let subdir = testDir.appendingPathComponent("subdir", isDirectory: true)

        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)
        try FileManager.default.createDirectory(
            at: subdir,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Only count files, not directories
        let files = try FileManagerUtils.enumerateFiles(in: testDir) { url in
            var isDirectory: ObjCBool = false
            FileManager.default.fileExists(
                atPath: url.path,
                isDirectory: &isDirectory
            )
            return !isDirectory.boolValue
        }
        #expect(files.count == 2)
        #expect(files.contains(file1))
        #expect(files.contains(file2))
    }

    @Test("Enumerate files with filter")
    func enumerateFilesWithFilter() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let file1 = testDir.appendingPathComponent("file1.txt")
        let file2 = testDir.appendingPathComponent("file2.dat")

        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)

        let txtFiles = try FileManagerUtils.enumerateFiles(in: testDir) { url in
            url.pathExtension == "txt"
        }

        #expect(txtFiles.count == 1)
        #expect(txtFiles.contains(file1))
    }

    // MARK: - Utility Tests

    @Test("Attributes of item returns attributes")
    func attributesOfItemReturnsAttributes() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let testFile = testDir.appendingPathComponent("test.txt")
        try "test content".write(
            to: testFile,
            atomically: true,
            encoding: .utf8
        )

        let attributes = try FileManagerUtils.attributesOfItem(at: testFile)
        #expect(attributes[.size] != nil)
        #expect(attributes[.creationDate] != nil)
        #expect(attributes[.modificationDate] != nil)
    }

    @Test("Calculate directory size returns correct size")
    func calculateDirectorySizeReturnsCorrectSize() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let file1 = testDir.appendingPathComponent("file1.txt")
        let file2 = testDir.appendingPathComponent("file2.txt")

        try "content1".write(to: file1, atomically: true, encoding: .utf8)
        try "content2".write(to: file2, atomically: true, encoding: .utf8)

        let size = try FileManagerUtils.calculateDirectorySize(in: testDir)
        #expect(size > 0)
    }

    @Test("Remove old files removes old files")
    func removeOldFilesRemovesOldFiles() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }
        try FileManagerUtils.ensureDirectoryExists(testDir)

        let oldFile = testDir.appendingPathComponent("old.txt")
        let newFile = testDir.appendingPathComponent("new.txt")

        try "old content".write(to: oldFile, atomically: true, encoding: .utf8)
        try "new content".write(to: newFile, atomically: true, encoding: .utf8)

        // Set old file modification date to 2 days ago
        let oldDate = Date().addingTimeInterval(-2 * 24 * 60 * 60)
        try FileManager.default.setAttributes(
            [.modificationDate: oldDate],
            ofItemAtPath: oldFile.path
        )

        try FileManagerUtils.removeOldFiles(
            in: testDir,
            olderThan: Date().addingTimeInterval(-1 * 24 * 60 * 60)
        )
        #expect(!FileManagerUtils.fileExists(at: oldFile))
        #expect(FileManagerUtils.fileExists(at: newFile))
    }

    // MARK: - Error Handling Tests

    @Test("Operations throw appropriate errors")
    func operationsThrowAppropriateErrors() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        let nonExistentFile = testDir.appendingPathComponent("nonexistent.txt")

        // Test fileExists with non-existent file
        #expect(!FileManagerUtils.fileExists(at: nonExistentFile))

        // Test removeFile with non-existent file
        do {
            try FileManagerUtils.removeFile(at: nonExistentFile)
            throw TestError.unexpectedSuccess("Should have thrown an error")
        } catch {
            #expect(error is FileManagerError)
        }

        // Test attributesOfItem with non-existent file
        do {
            _ = try FileManagerUtils.attributesOfItem(at: nonExistentFile)
            throw TestError.unexpectedSuccess("Should have thrown an error")
        } catch {
            #expect(error is FileManagerError)
        }
    }

    // MARK: - Setup Test

    @Test("Setup test directory")
    func setupTestDirectory() throws {
        let testDir = try createUniqueTestDirectory()
        defer { cleanupTestDirectory(testDir) }

        // Verify the directory can be created and cleaned up
        try FileManagerUtils.ensureDirectoryExists(testDir)
        #expect(FileManagerUtils.fileExists(at: testDir))

        cleanupTestDirectory(testDir)
        #expect(!FileManagerUtils.fileExists(at: testDir))
    }
}
