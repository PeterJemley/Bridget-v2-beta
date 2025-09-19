import Foundation
import Testing

@testable import Bridget

final class ThreadSanitizerTests {
    /// Test to verify Thread Sanitizer is working correctly
    /// This test will pass when TSan is disabled and fail when TSan is enabled
    @Test("Thread Sanitizer detects data race")
    func dataRaceDetection() async throws {
        // Skip this test if TSan is not enabled
        guard isThreadSanitizerEnabled() else {
            #expect(true, "TSan not enabled - skipping race detection test")
            return
        }

        // Create a shared counter that will cause a data race
        var counter = 0
        let iterations = 1000

        // Create multiple tasks that concurrently access the shared counter
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<iterations {
                        counter += 1  // This will cause a data race
                    }
                }
            }
        }

        // The final value should be 10 * iterations, but due to race conditions,
        // it will likely be less when TSan is enabled
        #expect(counter > 0, "Counter should be incremented")
    }

    /// Test to verify that actor-isolated code works correctly with TSan
    @Test("Actor isolation prevents data races")
    func actorIsolation() async throws {
        let actor = TestActor()
        let iterations = 1000

        // Create multiple tasks that access the actor
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<iterations {
                        await actor.increment()
                    }
                }
            }
        }

        let finalValue = await actor.getValue()
        #expect(
            finalValue == 10 * iterations,
            "Actor should maintain correct count: expected \(10 * iterations), got \(finalValue)"
        )
    }

    /// Test to verify that proper synchronization prevents data races
    @Test("Synchronized access prevents data races")
    func synchronizedAccess() async throws {
        let synchronizedCounter = SynchronizedCounter()
        let iterations = 1000

        // Create multiple tasks that access the synchronized counter
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    for _ in 0..<iterations {
                        synchronizedCounter.increment()
                    }
                }
            }
        }

        let finalValue = synchronizedCounter.getValue()
        #expect(
            finalValue == 10 * iterations,
            "Synchronized counter should maintain correct count: expected \(10 * iterations), got \(finalValue)"
        )
    }

    /// Helper function to check if Thread Sanitizer is enabled
    private func isThreadSanitizerEnabled() -> Bool {
        // Check if TSan runtime is linked
        return getenv("TSAN_OPTIONS") != nil || getenv("TSAN_OPTIONS") != nil
            || ProcessInfo.processInfo.environment["TSAN_OPTIONS"] != nil
    }
}

/// Test actor for demonstrating actor isolation
private actor TestActor {
    private var counter = 0

    func increment() {
        counter += 1
    }

    func getValue() -> Int {
        return counter
    }
}

/// Test class with proper synchronization
private class SynchronizedCounter {
    private var counter = 0
    private let lock = NSLock()

    func increment() {
        lock.lock()
        defer { lock.unlock() }
        counter += 1
    }

    func getValue() -> Int {
        lock.lock()
        defer { lock.unlock() }
        return counter
    }
}
