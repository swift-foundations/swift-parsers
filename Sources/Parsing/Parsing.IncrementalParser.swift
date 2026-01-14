//
//  Parsing.IncrementalParser.swift
//  swift-parsing
//
//  Protocol for incremental/streaming parsers.
//

extension Parsing {
    /// A parser that can process input incrementally.
    ///
    /// Unlike regular parsers which consume complete input, incremental
    /// parsers maintain state and emit outputs as they become available.
    ///
    /// ## State Machine
    ///
    /// Incremental parsers are state machines:
    /// 1. Start with `initial` state
    /// 2. Call `feed` with each input element
    /// 3. Emit outputs when available
    /// 4. Call `finish` at end of input
    ///
    /// ## Example
    ///
    /// ```swift
    /// struct LineParser: Parsing.IncrementalParser {
    ///     static var initial: [UInt8] { [] }
    ///
    ///     static func feed(_ byte: UInt8, state: inout [UInt8]) -> [String] {
    ///         if byte == 0x0A { // newline
    ///             defer { state = [] }
    ///             return [String(decoding: state, as: UTF8.self)]
    ///         }
    ///         state.append(byte)
    ///         return []
    ///     }
    ///
    ///     static func finish(state: inout [UInt8]) -> [String] {
    ///         if state.isEmpty { return [] }
    ///         return [String(decoding: state, as: UTF8.self)]
    ///     }
    /// }
    /// ```
    public protocol IncrementalParser<Element, Output> {
        /// Input element type.
        associatedtype Element: Sendable

        /// Output type produced.
        associatedtype Output: Sendable

        /// Parser state type.
        associatedtype State: Sendable

        /// Initial parser state.
        static var initial: State { get }

        /// Feeds an element to the parser.
        ///
        /// - Parameters:
        ///   - element: Input element.
        ///   - state: Parser state (modified).
        /// - Returns: Any outputs produced (may be empty).
        static func feed(_ element: Element, state: inout State) -> [Output]

        /// Signals end of input.
        ///
        /// - Parameter state: Parser state (modified).
        /// - Returns: Any final outputs (may be empty).
        static func finish(state: inout State) -> [Output]
    }
}
