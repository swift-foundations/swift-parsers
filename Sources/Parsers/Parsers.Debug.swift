//
//  Parser.Debug.swift
//  swift-parsing
//
//  Debugging tools for parser development.
//
//  ## Design
//
//  These tools help diagnose parser behavior during development:
//
//  - Trace: Log parser entry/exit with input state
//  - Profile: Collect timing and invocation statistics
//
//  Both wrap existing parsers, adding instrumentation without
//  changing parsing behavior.
//

public import Clocks
public import ISO_9945_Kernel_Clock
public import Synchronization

extension Parser {
    /// Namespace for debugging types.
    public enum Debug: Sendable {}
}

// MARK: - Trace

extension Parser.Debug {
    /// Wraps a parser to trace its execution.
    ///
    /// Logs when the parser is entered and whether it succeeded or failed,
    /// along with input state information.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let traced = parser.trace("myParser")
    /// // Logs:
    /// // [myParser] entering at offset 0
    /// // [myParser] succeeded, consumed 5 bytes
    /// ```
    public struct Trace<P: Parser.`Protocol`>
    where P.Input: Swift.Collection {
        /// The wrapped parser.
        @usableFromInline
        let inner: P

        /// Label for log messages.
        public let label: String

        /// Output function for log messages.
        @usableFromInline
        let output: (String) -> Void

        /// Creates a tracing wrapper.
        ///
        /// - Parameters:
        ///   - inner: The parser to trace.
        ///   - label: Label for log messages.
        ///   - output: Function to output log messages. Default `print`.
        @inlinable
        public init(
            _ inner: P,
            label: String,
            output: @escaping (String) -> Void = { print($0) }
        ) {
            self.inner = inner
            self.label = label
            self.output = output
        }
    }
}

extension Parser.Debug.Trace: Parser.`Protocol` {
    public typealias Input = P.Input
    public typealias Output = P.Output
    public typealias Failure = P.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        let startCount = input.count
        output("[\(label)] entering at offset \(startCount)")

        do throws(P.Failure) {
            let result = try inner.parse(&input)
            let consumed = startCount - input.count
            output("[\(label)] succeeded, consumed \(consumed) bytes")
            return result
        } catch {
            let consumed = startCount - input.count
            output("[\(label)] failed after consuming \(consumed) bytes: \(error)")
            throw error
        }
    }
}

// MARK: - Profile

extension Parser.Debug {
    /// Collects statistics about parser execution.
    ///
    /// Tracks invocation count, success/failure rates, and timing.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let profiled = parser.profile("myParser")
    /// // ... use parser multiple times ...
    /// print(profiled.stats.report())
    /// ```
    public struct Profile<P: Parser.`Protocol`> {
        /// The wrapped parser.
        @usableFromInline
        let inner: P

        /// Label for reporting.
        public let label: String

        /// Collected statistics.
        public let stats: Stats

        /// Creates a profiling wrapper.
        ///
        /// - Parameters:
        ///   - inner: The parser to profile.
        ///   - label: Label for reports.
        @inlinable
        public init(_ inner: P, label: String) {
            self.inner = inner
            self.label = label
            self.stats = Stats()
        }
    }
}

// MARK: - Stats

extension Parser.Debug.Profile {
    /// Statistics collected from parser execution.
    ///
    /// ## Safety Invariant
    ///
    /// All mutable counters live in `_state` and are guarded by an internal
    /// `Mutex<State>`. Every read and mutation (`recordSuccess`,
    /// `recordFailure`, `reset`, and every accessor) routes through
    /// `_state.withLock`, so concurrent recording from multiple tasks/threads
    /// is safe without external synchronization. See [MEM-SAFE-024] Category A.
    public final class Stats: @unchecked Sendable {
        @usableFromInline
        let _state: Mutex<State>

        /// Creates empty stats.
        @inlinable
        public init() {
            _state = Mutex(State())
        }
    }
}

extension Parser.Debug.Profile.Stats {
    /// The mutable counters, always accessed through `_state`'s `Mutex`.
    @usableFromInline
    struct State: Sendable {
        @usableFromInline var invocations: Int = 0
        @usableFromInline var successes: Int = 0
        @usableFromInline var failures: Int = 0
        @usableFromInline var totalDuration: Duration = .zero
        @usableFromInline var minDuration: Duration? = nil
        @usableFromInline var maxDuration: Duration = .zero

        @usableFromInline
        init() {}
    }
}

extension Parser.Debug.Profile.Stats {
    /// Total number of invocations.
    public var invocations: Int { _state.withLock { $0.invocations } }

    /// Number of successful parses.
    public var successes: Int { _state.withLock { $0.successes } }

    /// Number of failed parses.
    public var failures: Int { _state.withLock { $0.failures } }

    /// Total time spent parsing.
    public var totalDuration: Duration { _state.withLock { $0.totalDuration } }

    /// Minimum parse time.
    public var minDuration: Duration? { _state.withLock { $0.minDuration } }

    /// Maximum parse time.
    public var maxDuration: Duration { _state.withLock { $0.maxDuration } }

    /// Records a successful parse.
    @inlinable
    package func recordSuccess(elapsed: Duration) {
        _state.withLock { state in
            state.invocations += 1
            state.successes += 1
            state.totalDuration += elapsed
            if let min = state.minDuration {
                state.minDuration = Swift.min(min, elapsed)
            } else {
                state.minDuration = elapsed
            }
            state.maxDuration = Swift.max(state.maxDuration, elapsed)
        }
    }

    /// Records a failed parse.
    @inlinable
    package func recordFailure(elapsed: Duration) {
        _state.withLock { state in
            state.invocations += 1
            state.failures += 1
            state.totalDuration += elapsed
            if let min = state.minDuration {
                state.minDuration = Swift.min(min, elapsed)
            } else {
                state.minDuration = elapsed
            }
            state.maxDuration = Swift.max(state.maxDuration, elapsed)
        }
    }

    /// Success rate (0.0 to 1.0).
    public var successRate: Double {
        _state.withLock { state in
            guard state.invocations > 0 else { return 0 }
            return Double(state.successes) / Double(state.invocations)
        }
    }

    /// Average parse time.
    public var averageDuration: Duration {
        _state.withLock { state in
            guard state.invocations > 0 else { return .zero }
            return state.totalDuration / state.invocations
        }
    }

    /// Generates a human-readable report.
    public func report(label: String = "Parser") -> String {
        // Snapshot under a single lock acquisition so the report is internally
        // consistent even under concurrent recording.
        let snapshot = _state.withLock { $0 }

        guard snapshot.invocations > 0 else {
            return "\(label): no invocations"
        }

        let successPercent = Int(Double(snapshot.successes) / Double(snapshot.invocations) * 100)
        let average = snapshot.totalDuration / snapshot.invocations
        let minStr = snapshot.minDuration?.formatted(.duration) ?? "N/A"

        return """
            \(label) Statistics:
              Invocations: \(snapshot.invocations)
              Successes:   \(snapshot.successes) (\(successPercent)%)
              Failures:    \(snapshot.failures)
              Total time:  \(snapshot.totalDuration.formatted(.duration))
              Average:     \(average.formatted(.duration))
              Min:         \(minStr)
              Max:         \(snapshot.maxDuration.formatted(.duration))
            """
    }

    /// Resets all statistics.
    public func reset() {
        _state.withLock { state in
            state = State()
        }
    }
}

extension Parser.Debug.Profile: Parser.`Protocol` {
    public typealias Input = P.Input
    public typealias Output = P.Output
    public typealias Failure = P.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        let start = Clock.Continuous.now

        do throws(P.Failure) {
            let result = try inner.parse(&input)
            let elapsed = Clock.Continuous.now - start
            stats.recordSuccess(elapsed: elapsed)
            return result
        } catch {
            let elapsed = Clock.Continuous.now - start
            stats.recordFailure(elapsed: elapsed)
            throw error
        }
    }
}

// MARK: - Parser Extensions

extension Parser.`Protocol` where Input: Swift.Collection {
    /// Wraps this parser with tracing.
    ///
    /// - Parameters:
    ///   - label: Label for log messages.
    ///   - output: Output function. Default `print`.
    /// - Returns: A tracing parser wrapper.
    @inlinable
    public func trace(
        _ label: String,
        output: @escaping (String) -> Void = { print($0) }
    ) -> Parser.Debug.Trace<Self> {
        Parser.Debug.Trace(self, label: label, output: output)
    }
}

extension Parser.`Protocol` {
    /// Wraps this parser with profiling.
    ///
    /// - Parameter label: Label for reports.
    /// - Returns: A profiling parser wrapper.
    @inlinable
    public func profile(_ label: String) -> Parser.Debug.Profile<Self> {
        Parser.Debug.Profile(self, label: label)
    }
}

// MARK: - Convenience Accessors

extension Parser {
    /// Access to debug types via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.debug.Trace(parser, label: "myParser")
    /// Parser.debug.Profile(parser, label: "myParser")
    /// ```
    @inlinable
    public static var debug: Debug.Type { Debug.self }
}
