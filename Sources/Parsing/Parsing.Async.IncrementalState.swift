//
//  Parsing.Async.IncrementalState.swift
//  swift-parsing
//
//  Actor managing incremental parse state.
//

import Async

extension Parsing.Async {
    /// Actor managing incremental parse state.
    @usableFromInline
    actor IncrementalState<P: Parsing.IncrementalParser>: Sendable {
        @usableFromInline
        var iterator: Async.Stream<P.Element>.Iterator

        @usableFromInline
        var parserState: P.State

        @usableFromInline
        var pendingOutputs: [P.Output] = []

        @usableFromInline
        var upstreamDone: Bool = false

        @inlinable
        init(upstream: Async.Stream<P.Element>) {
            self.iterator = upstream.makeAsyncIterator()
            self.parserState = P.initial
        }
    }
}

extension Parsing.Async.IncrementalState {
    @inlinable
    func next() async -> P.Output? {
        // Return pending outputs first
        if !pendingOutputs.isEmpty {
            return pendingOutputs.removeFirst()
        }

        // Feed more input
        while !upstreamDone {
            guard let element = await iterator.next() else {
                upstreamDone = true
                // Flush remaining
                let finals = P.finish(state: &parserState)
                if !finals.isEmpty {
                    pendingOutputs = Array(finals.dropFirst())
                    return finals.first
                }
                return nil
            }

            let outputs = P.feed(element, state: &parserState)
            if !outputs.isEmpty {
                pendingOutputs = Array(outputs.dropFirst())
                return outputs.first
            }
        }

        return nil
    }
}

// MARK: - Async.Stream Extension

extension Async.Stream {
    /// Parses stream elements using an incremental parser.
    ///
    /// - Parameter parser: The incremental parser type.
    /// - Returns: Stream of parsed outputs.
    public func parse<P: Parsing.IncrementalParser>(
        with parser: P.Type
    ) -> Async.Stream<P.Output>
    where Element == P.Element {
        let upstream = self
        return Async.Stream<P.Output> {
            let state = Parsing.Async.IncrementalState<P>(upstream: upstream)
            return Async.Stream<P.Output>.Iterator {
                await state.next()
            }
        }
    }
}
