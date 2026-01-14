//
//  Parsing.Async.StreamParseState.swift
//  swift-parsing
//
//  Actor managing repeated parsing from an async sequence.
//

import Async
import Container_Primitives

extension Parsing.Async {
    /// Actor managing repeated parsing from an async sequence.
    @usableFromInline
    actor StreamParseState<P: Parsing.Parser & Sendable, S: AsyncSequence & Sendable>: Sendable
    where P.Input == ArraySlice<UInt8>, P.Output: Sendable, S.Element == UInt8 {

        @usableFromInline
        nonisolated(unsafe) var iterator: S.AsyncIterator

        @usableFromInline
        let parser: P

        @usableFromInline
        let bufferSize: Int

        @usableFromInline
        var buffer: Deque<UInt8> = Deque()

        @usableFromInline
        var upstreamDone: Bool = false

        @inlinable
        init(parser: P, input: S, bufferSize: Int) {
            self.iterator = input.makeAsyncIterator()
            self.parser = parser
            self.bufferSize = bufferSize
        }
    }
}

extension Parsing.Async.StreamParseState {
    @inlinable
    func next() async -> P.Output? {
        while true {
            // Try to parse from buffer
            if !buffer.isEmpty {
                // Convert deque to array for parsing
                var bytes: [UInt8] = []
                bytes.reserveCapacity(buffer.count)
                for i in 0..<buffer.count {
                    bytes.append(buffer[i])
                }
                var slice = ArraySlice(bytes)
                if let output = try? parser.parse(&slice) {
                    // Remove consumed bytes from front
                    let consumed = bytes.count - slice.count
                    for _ in 0..<consumed {
                        _ = try? buffer.pop.front()
                    }
                    return output
                }
            }

            // Need more data or exhausted
            if upstreamDone {
                return nil
            }

            // Buffer more input
            var bytesRead = 0
            while bytesRead < bufferSize, !upstreamDone {
                do {
                    guard let byte = try await iterator.next() else {
                        upstreamDone = true
                        break
                    }
                    buffer.push.back(byte)
                    bytesRead += 1
                } catch {
                    upstreamDone = true
                    break
                }
            }

            // If we couldn't read anything and we're done, exit
            if bytesRead == 0 && upstreamDone && buffer.isEmpty {
                return nil
            }
        }
    }
}

// MARK: - Parser Extension

extension Parsing.Parser where Self: Sendable, Output: Sendable {
    /// Creates a stream that repeatedly applies this parser to buffered input.
    ///
    /// Buffers bytes from the async sequence and parses repeatedly until
    /// the parser fails or input is exhausted.
    ///
    /// - Parameters:
    ///   - input: Async sequence providing input bytes.
    ///   - bufferSize: Maximum buffer size before attempting parse.
    /// - Returns: Stream of parsed values.
    @inlinable
    public func stream<S: AsyncSequence & Sendable>(
        from input: S,
        bufferSize: Int = 4096
    ) -> Async.Stream<Output>
    where S.Element == UInt8, Input == ArraySlice<UInt8> {
        let parser = self

        return Async.Stream<Output> {
            let state = Parsing.Async.StreamParseState(
                parser: parser,
                input: input,
                bufferSize: bufferSize
            )
            return Async.Stream<Output>.Iterator {
                await state.next()
            }
        }
    }
}
