import Foundation

/// Thread-safe cancellation flag passed into model adapters between token callbacks.
public final class CancellationToken: @unchecked Sendable {
    private var cancelled = false
    private let lock = NSLock()

    public init() {}

    public func cancel() {
        lock.withLock { cancelled = true }
    }

    public func reset() {
        lock.withLock { cancelled = false }
    }

    public var isCancelled: Bool {
        lock.withLock { cancelled }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
