import Foundation

public protocol ClockProtocol {
  /// Current point in time
  var now: Date { get }
  /// Calendar to use for date component calculations
  var calendar: Calendar { get }
}

/// System-backed clock using device time and current calendar
public final class SystemClock: ClockProtocol {
  public static let shared = SystemClock()

  public var now: Date { Date() }
  public var calendar: Calendar { Calendar.current }

  private init() {}
}
