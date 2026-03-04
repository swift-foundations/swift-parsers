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
    public struct Trace<P: Parser.`Protocol`>: Sendable
    where P: Sendable, P.Input: Swift.Collection {
        /// The wrapped parser.
        @usableFromInline
        let inner: P

        /// Label for log messages.
        public let label: String

        /// Output function for log messages.
        @usableFromInline
        let output: @Sendable (String) -> Void

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
            output: @escaping @Sendable (String) -> Void = { print($0) }
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

        do {
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
    public struct Profile<P: Parser.`Protocol`>: Sendable
    where P: Sendable {
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
    public final class Stats: @unchecked Sendable {
        /// Total number of invocations.
        @usableFromInline
        var _invocations: Int = 0

        /// Number of successful parses.
        @usableFromInline
        var _successes: Int = 0

        /// Number of failed parses.
        @usableFromInline
        var _failures: Int = 0

        /// Total time spent parsing.
        @usableFromInline
        var _totalDuration: Duration = .zero

        /// Minimum parse time.
        @usableFromInline
        var _minDuration: Duration? = nil

        /// Maximum parse time.
        @usableFromInline
        var _maxDuration: Duration = .zero

        /// Total number of invocations.
        public var invocations: Int { _invocations }

        /// Number of successful parses.
        public var successes: Int { _successes }

        /// Number of failed parses.
        public var failures: Int { _failures }

        /// Total time spent parsing.
        public var totalDuration: Duration { _totalDuration }

        /// Minimum parse time.
        public var minDuration: Duration? { _minDuration }

        /// Maximum parse time.
        public var maxDuration: Duration { _maxDuration }

        /// Creates empty stats.
        @inlinable
        public init() {}

        /// Records a successful parse.
        @inlinable
        func recordSuccess(elapsed: Duration) {
            _invocations += 1
            _successes += 1
            _totalDuration += elapsed
            if let min = _minDuration {
                _minDuration = Swift.min(min, elapsed)
            } else {
                _minDuration = elapsed
            }
            _maxDuration = Swift.max(_maxDuration, elapsed)
        }

        /// Records a failed parse.
        @inlinable
        func recordFailure(elapsed: Duration) {
            _invocations += 1
            _failures += 1
            _totalDuration += elapsed
            if let min = _minDuration {
                _minDuration = Swift.min(min, elapsed)
            } else {
                _minDuration = elapsed
            }
            _maxDuration = Swift.max(_maxDuration, elapsed)
        }

        /// Success rate (0.0 to 1.0).
        public var successRate: Double {
            guard _invocations > 0 else { return 0 }
            return Double(_successes) / Double(_invocations)
        }

        /// Average parse time.
        public var averageDuration: Duration {
            guard _invocations > 0 else { return .zero }
            return _totalDuration / _invocations
        }

        /// Generates a human-readable report.
        public func report(label: String = "Parser") -> String {
            guard _invocations > 0 else {
                return "\(label): no invocations"
            }

            let successPercent = Int(successRate * 100)
            let minStr = _minDuration?.formatted(.duration) ?? "N/A"

            return """
            \(label) Statistics:
              Invocations: \(_invocations)
              Successes:   \(_successes) (\(successPercent)%)
              Failures:    \(_failures)
              Total time:  \(_totalDuration.formatted(.duration))
              Average:     \(averageDuration.formatted(.duration))
              Min:         \(minStr)
              Max:         \(_maxDuration.formatted(.duration))
            """
        }

        /// Resets all statistics.
        public func reset() {
            _invocations = 0
            _successes = 0
            _failures = 0
            _totalDuration = .zero
            _minDuration = nil
            _maxDuration = .zero
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

        do {
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

extension Parser.`Protocol` where Self: Sendable, Input: Swift.Collection {
    /// Wraps this parser with tracing.
    ///
    /// - Parameters:
    ///   - label: Label for log messages.
    ///   - output: Output function. Default `print`.
    /// - Returns: A tracing parser wrapper.
    @inlinable
    public func trace(
        _ label: String,
        output: @escaping @Sendable (String) -> Void = { print($0) }
    ) -> Parser.Debug.Trace<Self> {
        Parser.Debug.Trace(self, label: label, output: output)
    }
}

extension Parser.`Protocol` where Self: Sendable {
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
