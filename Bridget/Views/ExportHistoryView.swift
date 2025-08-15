import OSLog
import SwiftUI

public struct ExportHistoryView: View {
  @State private var exportedFiles: [ExportedFile] = []
  @State private var selectedFileURL: URL?
  @State private var showingFilePreview = false

  private let fileManager = FileManager.default
  private let logger = Logger(subsystem: "Bridget", category: "ExportHistoryView")

  public var body: some View {
    NavigationStack {
      if exportedFiles.isEmpty {
        Text("No export files found.")
          .foregroundStyle(.secondary)
          .padding()
          .navigationTitle("Export History")
      } else {
        List {
          ForEach($exportedFiles) { $file in
            Button {
              selectedFileURL = $file.wrappedValue.url
              showingFilePreview = true
            } label: {
              HStack {
                Image(systemName: "doc.plaintext")
                  .foregroundStyle(.blue)
                  .frame(width: 24)
                VStack(alignment: .leading) {
                  Text($file.wrappedValue.name)
                    .lineLimit(1)
                    .truncationMode(.middle)
                  Text($file.wrappedValue.dateText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                  .foregroundStyle(.tertiary)
              }
            }
          }
          .onDelete(perform: deleteFiles)
        }
        .navigationTitle("Export History")
        .toolbar {
          ToolbarItem(placement: .topBarTrailing) {
            EditButton()
          }
        }
        .sheet(isPresented: $showingFilePreview) {
          if let url = selectedFileURL {
            ShareLink(item: url) {
              Text("Share \(url.lastPathComponent)")
                .padding()
            }
          }
        }
      }
    }
    .task {
      await loadExportedFiles()
    }
  }

  /// Load exported NDJSON files from known export directories
  private func loadExportedFiles() async {
    var files: [ExportedFile] = []

    // Gather from both Documents and Downloads (if macOS)
    let documentURLs = [FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!]
    #if os(macOS)
      let downloadsURLs = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)
    #else
      let downloadsURLs: [URL] = []
    #endif

    let searchURLs = documentURLs + downloadsURLs

    for baseURL in searchURLs {
      do {
        let contents = try fileManager.contentsOfDirectory(at: baseURL, includingPropertiesForKeys: [.contentModificationDateKey], options: [.skipsHiddenFiles])
        let ndjsonFiles = contents.filter { $0.pathExtension.lowercased() == "ndjson" }

        for fileURL in ndjsonFiles {
          let resourceValues = try fileURL.resourceValues(forKeys: [.contentModificationDateKey])
          let modDate = resourceValues.contentModificationDate ?? Date.distantPast
          let exportedFile = ExportedFile(url: fileURL, name: fileURL.lastPathComponent, date: modDate)
          files.append(exportedFile)
        }
      } catch {
        logger.error("Failed to list directory \(baseURL.path): \(error.localizedDescription)")
      }
    }

    // Sort files newest first
    files.sort { $0.date > $1.date }

    await MainActor.run {
      exportedFiles = files
    }
  }

  /// Delete files from disk and update list
  private func deleteFiles(at offsets: IndexSet) {
    for index in offsets {
      let file = exportedFiles[index]
      do {
        try fileManager.removeItem(at: file.url)
      } catch {
        logger.error("Failed to delete file \(file.url.path): \(error.localizedDescription)")
      }
    }
    exportedFiles.remove(atOffsets: offsets)
  }
}

/// Represents an exported file with metadata to display
struct ExportedFile: Identifiable {
  let id = UUID()
  var url: URL
  var name: String
  var date: Date

  var dateText: String {
    DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
  }
}

#Preview {
  ExportHistoryView()
}

#Preview("With Mock Data") {
  let mockView = ExportHistoryView()
  // Note: In a real preview, you would inject mock data here
  // For now, this shows the empty state
  return mockView
}
