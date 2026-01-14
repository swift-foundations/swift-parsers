//
//  Parsing.Async.swift
//  swift-parsing
//
//  Async streaming integration with swift-async.
//
//  ## Design
//
//  Integrates parsing with Async.Stream for incremental/streaming parsing.
//  Follows swift-async patterns:
//
//  - Concrete types (Async.Stream<T>) not protocol erasure
//  - Sendable-first for concurrent safety
//  - Actor-based state for stateful operations
//
//  ## Usage
//
//  ```swift
//  let byteStream: Async.Stream<UInt8> = ...
//  let parsed = byteStream.parseChunked(with: jsonParser, chunkSize: 4096)
//  for await value in parsed {
//      process(value)
//  }
//  ```
//

import Async

// MARK: - Namespace

extension Parsing {
    /// Namespace for async parsing types.
    public enum Async: Sendable {}
}

// MARK: - Convenience

extension Parsing {
    /// Access to async parsing types.
    @inlinable
    public static var async: Async.Type { Async.self }
}
