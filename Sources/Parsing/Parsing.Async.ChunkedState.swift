//
//  Parsing.Async.ChunkedState.swift
//  swift-parsing
//
//  Actor managing chunked parse state for byte streams.
//

import Async
import Container_Primitives

extension Parsing.Async {
    /// Actor managing chunked parse state.
    @usableFromInline
    actor ChunkedState<P: Parsing.Parser & Sendable>: Sendable
    where P.Input == ArraySlice<UInt8>, P.Output: Sendable {

        @usableFromInline
        var iterator: Async.Stream<UInt8>.Iterator

        @usableFromInline
        let parser: P

        @usableFromInline
        let chunkSize: Int

        @usableFromInline
        let delimiter: UInt8?

        @usableFromInline
        var buffer: Deque<UInt8> = Deque()

        @usableFromInline
        var upstreamDone: Bool = false

        @inlinable
        init(upstream: Async.Stream<UInt8>, parser: P, chunkSize: Int, delimiter: UInt8?) {
            self.iterator = upstream.makeAsyncIterator()
            self.parser = parser
            self.chunkSize = chunkSize
            self.delimiter = delimiter
        }
    }
}

extension Parsing.Async.ChunkedState {
    @inlinable
    func next() async -> P.Output? {
        while true {
            // Check if we have enough data to parse
            if let delimiter = delimiter {
                // Delimiter-based chunking - find delimiter index
                var delimiterIndex: Int? = nil
                for i in 0..<buffer.count {
                    if buffer[i] == delimiter {
                        delimiterIndex = i
                        break
                    }
                }

                if let idx = delimiterIndex {
                    // Extract chunk up to delimiter
                    var chunk: [UInt8] = []
                    chunk.reserveCapacity(idx)
                    for _ in 0..<idx {
                        if let byte = try? buffer.pop.front() {
                            chunk.append(byte)
                        }
                    }
                    // Remove delimiter
                    _ = try? buffer.pop.front()

                    if let output = try? parser.parse(ArraySlice(chunk)) {
                        return output
                    }
                }
            } else if buffer.count >= chunkSize || upstreamDone {
                // Size-based chunking
                if !buffer.isEmpty {
                    let takeCount = min(chunkSize, buffer.count)
                    var chunk: [UInt8] = []
                    chunk.reserveCapacity(takeCount)
                    for _ in 0..<takeCount {
                        if let byte = try? buffer.pop.front() {
                            chunk.append(byte)
                        }
                    }

                    if let output = try? parser.parse(ArraySlice(chunk)) {
                        return output
                    }
                }
            }

            // Need more data
            if upstreamDone {
                // Try parsing remaining buffer
                if !buffer.isEmpty {
                    var chunk: [UInt8] = []
                    chunk.reserveCapacity(buffer.count)
                    while !buffer.isEmpty {
                        if let byte = try? buffer.pop.front() {
                            chunk.append(byte)
                        }
                    }
                    return try? parser.parse(ArraySlice(chunk))
                }
                return nil
            }

            // Fetch more from upstream
            guard let byte = await iterator.next() else {
                upstreamDone = true
                continue
            }
            buffer.push.back(byte)
        }
    }
}

// MARK: - Async.Stream Extension

extension Async.Stream where Element == UInt8 {
    /// Parses byte stream with automatic chunking.
    ///
    /// Buffers bytes into chunks, then applies a regular parser to each chunk.
    /// Useful for parsing protocols with delimited records.
    ///
    /// - Parameters:
    ///   - parser: Parser to apply to each chunk.
    ///   - chunkSize: Maximum bytes to buffer before parsing.
    ///   - delimiter: Optional delimiter byte to split chunks.
    /// - Returns: Stream of parsed values.
    public func parseChunked<P: Parsing.Parser>(
        with parser: P,
        chunkSize: Int = 4096,
        delimiter: UInt8? = nil
    ) -> Async.Stream<P.Output>
    where P.Input == ArraySlice<UInt8>, P: Sendable, P.Output: Sendable {
        let upstream = self
        let parserCopy = parser

        return Async.Stream<P.Output> {
            let state = Parsing.Async.ChunkedState(
                upstream: upstream,
                parser: parserCopy,
                chunkSize: chunkSize,
                delimiter: delimiter
            )

            return Async.Stream<P.Output>.Iterator {
                await state.next()
            }
        }
    }
}
