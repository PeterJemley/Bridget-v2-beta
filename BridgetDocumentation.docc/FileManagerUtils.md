# FileManagerUtils

Centralized file system operations utility for the Bridget project.

## Overview

`FileManagerUtils` provides a unified interface for all file system operations across the Bridget project. This utility eliminates code duplication and ensures consistent error handling and logging for file operations.

## Purpose

- **Eliminate Duplication**: Consolidate repeated FileManager patterns across services
- **Standardize Error Handling**: Provide consistent error types and logging
- **Improve Maintainability**: Single point of change for file operation logic
- **Ensure Consistency**: Uniform behavior across all file operations

## Key Features

### Directory Operations
- `ensureDirectoryExists(_:)` - Create directories with existence checks
- `documentsDirectory()` - Get system documents directory
- `downloadsDirectory()` - Get system downloads directory (macOS only)
- `temporaryDirectory()` - Get system temporary directory

### File Operations
- `createTemporaryFile(in:prefix:extension:)` - Create temporary files for atomic operations
- `createMarkerFile(at:)` - Create zero-byte marker files
- `atomicReplaceItem(at:with:)` - Perform atomic file replacement
- `removeFile(at:)` - Remove files with error handling

### File Enumeration
- `enumerateFiles(in:filter:properties:)` - List files with optional filtering
- `calculateDirectorySize(in:filter:)` - Calculate total directory size

### Cleanup Operations
- `removeOldFiles(in:olderThan:filter:)` - Remove files based on age
- `removeFilesMatchingPattern(in:pattern:)` - Remove files matching patterns

### File Information
- `fileExists(at:)` - Check file existence
- `attributesOfItem(at:)` - Get file attributes

## Usage Examples

### Directory Creation
```swift
// Create a directory if it doesn't exist
try FileManagerUtils.ensureDirectoryExists(cacheDirectory)

// Create directory from path string
try FileManagerUtils.ensureDirectoryExists(at: "/path/to/directory")
```

### Atomic File Operations
```swift
// Create temporary file for atomic replacement
let tempFile = try FileManagerUtils.createTemporaryFile(
    in: outputDirectory, 
    prefix: "export", 
    extension: "tmp"
)

// Write data to temporary file
try data.write(to: tempFile)

// Atomically replace destination file
try FileManagerUtils.atomicReplaceItem(at: destinationFile, with: tempFile)

// Create marker file for coordination
try FileManagerUtils.createMarkerFile(at: doneFile)
```

### File Enumeration and Filtering
```swift
// List all files in directory
let allFiles = try FileManagerUtils.enumerateFiles(in: directory)

// List only .txt files
let txtFiles = try FileManagerUtils.enumerateFiles(in: directory) { url in
    url.pathExtension == "txt"
}

// Calculate directory size
let totalSize = try FileManagerUtils.calculateDirectorySize(in: directory)
```

### Cleanup Operations
```swift
// Remove files older than 7 days
let cutoffDate = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
try FileManagerUtils.removeOldFiles(in: directory, olderThan: cutoffDate)

// Remove temporary files
try FileManagerUtils.removeFilesMatchingPattern(in: directory, pattern: ".*\\.tmp$")
```

### System Directories
```swift
// Get system directories
let documentsDir = try FileManagerUtils.documentsDirectory()
let tempDir = FileManagerUtils.temporaryDirectory()
let downloadsDir = FileManagerUtils.downloadsDirectory() // macOS only
```

## Error Handling

All operations throw `FileManagerError` with descriptive error messages:

```swift
do {
    try FileManagerUtils.ensureDirectoryExists(directory)
} catch let error as FileManagerError {
    switch error {
    case .directoryCreationFailed(let url, let underlyingError):
        print("Failed to create directory at \(url.path): \(underlyingError)")
    case .invalidDirectory(let url):
        print("Invalid directory path: \(url.path)")
    default:
        print("File operation failed: \(error.localizedDescription)")
    }
}
```

### Error Types
- `directoryCreationFailed` - Directory creation failed
- `fileReplacementFailed` - File replacement operation failed
- `fileEnumerationFailed` - File enumeration failed
- `fileRemovalFailed` - File removal failed
- `fileAttributesFailed` - Getting file attributes failed
- `fileExistsCheckFailed` - File existence check failed
- `invalidDirectory` - Invalid directory path
- `fileNotFound` - File not found
- `permissionDenied` - Permission denied
- `diskFull` - Disk full

## Migration Guide

### Before (Direct FileManager Usage)
```swift
// Directory creation
if !FileManager.default.fileExists(atPath: path) {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
}

// File enumeration
let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)

// File removal
try FileManager.default.removeItem(at: fileURL)
```

### After (FileManagerUtils Usage)
```swift
// Directory creation
try FileManagerUtils.ensureDirectoryExists(url)

// File enumeration
let files = try FileManagerUtils.enumerateFiles(in: directory)

// File removal
try FileManagerUtils.removeFile(at: fileURL)
```

## Best Practices

### 1. Always Use FileManagerUtils
- **Do**: Use `FileManagerUtils` for all file operations
- **Don't**: Use `FileManager.default` directly

### 2. Handle Errors Appropriately
- **Do**: Catch and handle `FileManagerError` types
- **Don't**: Ignore file operation errors

### 3. Use Atomic Operations for Critical Files
- **Do**: Use `atomicReplaceItem` for important files
- **Don't**: Write directly to destination files

### 4. Clean Up Temporary Files
- **Do**: Remove temporary files after use
- **Don't**: Leave temporary files in the file system

### 5. Use Appropriate Filtering
- **Do**: Use filters for file enumeration when possible
- **Don't**: Enumerate all files when you only need specific ones

## Integration Points

### Services Using FileManagerUtils
- `CacheService` - Cache directory management and file operations
- `RetryRecoveryService` - Checkpoint file management
- `BridgeDataExporter` - Atomic file export operations
- `MLPipelineBackgroundManager` - Cleanup operations
- `ExportHistoryView` - File enumeration and deletion

### Scripts Using FileManagerUtils
- `run_exporter.swift` - Atomic file export operations
- `run_baseline_test.swift` - Test directory creation
- `collect_golden_samples.swift` - Output directory creation

## Testing

The `FileManagerUtilsTests` suite provides comprehensive coverage:
- Directory operations (creation, existence checks)
- File operations (creation, replacement, removal)
- File enumeration and filtering
- Error handling and edge cases
- System directory access

Run tests to ensure file operations work correctly:
```bash
swift test --filter FileManagerUtilsTests
```

## Future Enhancements

### Potential Additions
- **Async Support**: Async versions of file operations for background queues
- **Progress Tracking**: Progress callbacks for large file operations
- **Batch Operations**: Optimized batch file operations
- **File Watching**: File system change monitoring
- **Compression**: Built-in file compression utilities

### Migration Path
- All new file operations should use `FileManagerUtils`
- Existing code should be migrated incrementally
- Direct `FileManager` usage should be flagged in code reviews

## Related Documentation

- [Data Processing Pipeline](DataProcessingPipeline.md) - File operations in data processing
- [Caching Strategy](CachingStrategy.md) - Cache file management
- [Error Handling](ErrorHandling.md) - Error handling patterns
- [Testing Workflow](TestingWorkflow.md) - Testing file operations

