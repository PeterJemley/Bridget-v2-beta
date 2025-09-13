import Foundation

/// A tiny, non-noisy logger that prints only when enabled.
/// Use for lightweight diagnostics without introducing heavy dependencies.
public struct LightweightLogger {
  public enum Level: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
  }

  public var isEnabled: Bool
  public var subsystem: String

  public init(subsystem: String, isEnabled: Bool = true) {
    self.subsystem = subsystem
    self.isEnabled = isEnabled
  }

  public func log(_ level: Level, _ message: @autoclosure () -> String) {
    guard isEnabled else { return }
    let ts = ISO8601DateFormatter().string(from: Date())
    print("[\(subsystem)] [\(level.rawValue)] [\(ts)] \(message())")
  }

  public func debug(_ message: @autoclosure () -> String) { log(.debug, message()) }
  public func info(_ message: @autoclosure () -> String) { log(.info, message()) }
  public func warning(_ message: @autoclosure () -> String) { log(.warning, message()) }
  public func error(_ message: @autoclosure () -> String) { log(.error, message()) }
}
