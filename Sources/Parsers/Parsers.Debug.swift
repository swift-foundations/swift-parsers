public import Clocks
public import Synchronization

extension Parser {

    public enum Debug: Sendable {}
}

extension Parser.Debug {

    public struct Trace<P: Parser.`Protocol`>
    where P.Input: Swift.Collection {

        @usableFromInline
        let inner: P

        public let label: String

        @usableFromInline
        let output: (String) -> Void

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

extension Parser.Debug {

    public struct Profile<P: Parser.`Protocol`> {

        @usableFromInline
        let inner: P

        public let label: String

        public let stats: Stats

        @inlinable
        public init(_ inner: P, label: String) {
            self.inner = inner
            self.label = label
            self.stats = Stats()
        }
    }
}

extension Parser.Debug.Profile {

    public final class Stats: @unchecked Sendable {
        @usableFromInline
        let _state: Mutex<State>

        @inlinable
        public init() {
            _state = Mutex(State())
        }
    }
}

extension Parser.Debug.Profile.Stats {

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

    public var invocations: Int { _state.withLock { $0.invocations } }

    public var successes: Int { _state.withLock { $0.successes } }

    public var failures: Int { _state.withLock { $0.failures } }

    public var totalDuration: Duration { _state.withLock { $0.totalDuration } }

    public var minDuration: Duration? { _state.withLock { $0.minDuration } }

    public var maxDuration: Duration { _state.withLock { $0.maxDuration } }

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

    public var successRate: Double {
        _state.withLock { state in
            guard state.invocations > 0 else { return 0 }
            return Double(state.successes) / Double(state.invocations)
        }
    }

    public var averageDuration: Duration {
        _state.withLock { state in
            guard state.invocations > 0 else { return .zero }
            return state.totalDuration / state.invocations
        }
    }

    public func report(label: String = "Parser") -> String {

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

extension Parser.`Protocol` where Input: Swift.Collection {

    @inlinable
    public func trace(
        _ label: String,
        output: @escaping (String) -> Void = { print($0) }
    ) -> Parser.Debug.Trace<Self> {
        Parser.Debug.Trace(self, label: label, output: output)
    }
}

extension Parser.`Protocol` {

    @inlinable
    public func profile(_ label: String) -> Parser.Debug.Profile<Self> {
        Parser.Debug.Profile(self, label: label)
    }
}

extension Parser {

    @inlinable
    public static var debug: Debug.Type { Debug.self }
}
