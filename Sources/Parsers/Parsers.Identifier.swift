//
//  Parser.Identifier.swift
//  swift-parsing
//
//  Identifier parsers for common identifier patterns.
//
//  ## Design
//
//  Identifiers are fundamental to parsing programming languages and data formats.
//  This module provides parsers for common identifier patterns:
//
//  - CStyle: Traditional C/C++/Java style `[a-zA-Z_][a-zA-Z0-9_]*`
//  - Custom: User-defined character classes
//
//  ## Usage
//
//  ```swift
//  let id = Parser.Identifier.CStyle()
//  var input = "myVariable123 = ..."[...].utf8
//  let count = try id.parse(&input)  // 13 (bytes consumed)
//  ```
//

extension Parser {
    /// Namespace for identifier parsing types.
    public enum Identifier: Sendable {}
}

// MARK: - C-Style Identifier

extension Parser.Identifier {
    /// Parses C-style identifiers: `[a-zA-Z_][a-zA-Z0-9_]*`
    ///
    /// This is the most common identifier format, used in C, C++, Java,
    /// JavaScript, Python, Swift, and many other languages.
    ///
    /// Returns the number of bytes consumed.
    ///
    /// ## Grammar
    ///
    /// ```
    /// identifier = start continue*
    /// start      = "a"..."z" | "A"..."Z" | "_"
    /// continue   = start | "0"..."9"
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let id = Parser.Identifier.CStyle()
    /// var input = "foo"[...].utf8
    /// let count = try id.parse(&input)  // 3
    /// ```
    public struct CStyle: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Identifier.CStyle: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Check for valid start character
        guard let first = input.first, Self.isStartChar(first) else {
            throw .predicateFailed(description: "identifier start character")
        }

        var count = 1
        input.removeFirst()

        // Consume continue characters
        while let byte = input.first, Self.isContinueChar(byte) {
            input.removeFirst()
            count += 1
        }

        return count
    }

    @inlinable
    package static func isStartChar(_ byte: UInt8) -> Bool {
        ASCII.Classification.isLetter(byte) || byte == .ascii.underline
    }

    @inlinable
    package static func isContinueChar(_ byte: UInt8) -> Bool {
        ASCII.Classification.isAlphanumeric(byte) || byte == .ascii.underline
    }
}

// MARK: - Custom Identifier

extension Parser.Identifier {
    /// Parses identifiers with custom character classes.
    ///
    /// Use this for languages with non-standard identifier rules.
    /// Returns the number of bytes consumed.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Allow hyphens in identifiers (like CSS, Lisp)
    /// let kebab = Parser.Identifier.Custom(
    ///     start: { ($0 >= 0x61 && $0 <= 0x7A) || $0 == 0x5F },  // a-z, _
    ///     continue: { ($0 >= 0x61 && $0 <= 0x7A) || $0 == 0x2D }  // a-z, -
    /// )
    /// ```
    public struct Custom: Sendable {
        @usableFromInline
        let isStart: @Sendable (UInt8) -> Bool

        @usableFromInline
        let isContinue: @Sendable (UInt8) -> Bool

        /// Creates a custom identifier parser.
        ///
        /// - Parameters:
        ///   - start: Predicate for valid start characters.
        ///   - continue: Predicate for valid continuation characters.
        @inlinable
        public init(
            start: @escaping @Sendable (UInt8) -> Bool,
            `continue`: @escaping @Sendable (UInt8) -> Bool
        ) {
            self.isStart = start
            self.isContinue = `continue`
        }
    }
}

extension Parser.Identifier.Custom: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Check for valid start character
        guard let first = input.first, isStart(first) else {
            throw .predicateFailed(description: "identifier start character")
        }

        var count = 1
        input.removeFirst()

        // Consume continue characters
        while let byte = input.first, isContinue(byte) {
            input.removeFirst()
            count += 1
        }

        return count
    }
}

// MARK: - Convenience Accessors

extension Parser {
    /// Access to identifier parsers via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.identifier.CStyle()
    /// Parser.identifier.Custom(start: { ... }, continue: { ... })
    /// ```
    @inlinable
    public static var identifier: Identifier.Type { Identifier.self }
}
