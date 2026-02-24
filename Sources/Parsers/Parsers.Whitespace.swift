//
//  Parser.Whitespace.swift
//  swift-parsing
//
//  Whitespace parsers for common whitespace patterns.
//
//  ## Design
//
//  Whitespace handling is split into distinct parsers:
//  - Horizontal: spaces and tabs
//  - Vertical: newlines (LF, CR, CRLF)
//  - `Any`: all whitespace
//  - Skip: infallible consumption of zero or more
//
//  This separation allows precise control over whitespace handling,
//  which is critical for line-oriented formats.
//

extension Parser {
    /// Namespace for whitespace parsing types.
    public enum Whitespace: Sendable {}
}

// MARK: - ASCII Constants

extension Parser.Whitespace {
    @usableFromInline
    static let space: UInt8 = 0x20       // ' '

    @usableFromInline
    static let tab: UInt8 = 0x09         // '\t'

    @usableFromInline
    static let lf: UInt8 = 0x0A          // '\n'

    @usableFromInline
    static let cr: UInt8 = 0x0D          // '\r'

    @usableFromInline
    static let formFeed: UInt8 = 0x0C    // '\f'

    @usableFromInline
    static let verticalTab: UInt8 = 0x0B // '\v'
}

// MARK: - Horizontal Whitespace

extension Parser.Whitespace {
    /// Parses one or more horizontal whitespace characters (space, tab).
    ///
    /// Fails if no horizontal whitespace is found.
    ///
    /// ## Grammar
    ///
    /// ```
    /// horizontal = (SPACE | TAB)+
    /// ```
    public struct Horizontal: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Whitespace.Horizontal: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias ParseOutput = Int
    public typealias Failure = Parser.Constraint.Error

    /// Parses horizontal whitespace and returns the count of bytes consumed.
    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> ParseOutput {
        var count = 0

        while let byte = input.first,
              byte == Parser.Whitespace.space || byte == Parser.Whitespace.tab {
            input.removeFirst()
            count += 1
        }

        guard count > 0 else {
            throw .countTooLow(expected: 1, got: 0)
        }

        return count
    }
}

// MARK: - Vertical Whitespace

extension Parser.Whitespace {
    /// Parses one or more vertical whitespace characters (newlines).
    ///
    /// Handles LF (\n), CR (\r), and CRLF (\r\n) sequences.
    /// CRLF is consumed as a single newline.
    ///
    /// ## Grammar
    ///
    /// ```
    /// vertical = (LF | CR LF? | CRLF)+
    /// ```
    public struct Vertical: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Whitespace.Vertical: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias ParseOutput = Int
    public typealias Failure = Parser.Constraint.Error

    /// Parses vertical whitespace and returns the count of newlines consumed.
    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> ParseOutput {
        var count = 0

        while let byte = input.first {
            if byte == Parser.Whitespace.lf {
                input.removeFirst()
                count += 1
            } else if byte == Parser.Whitespace.cr {
                input.removeFirst()
                count += 1
                // Consume following LF if present (CRLF)
                if input.first == Parser.Whitespace.lf {
                    input.removeFirst()
                }
            } else {
                break
            }
        }

        guard count > 0 else {
            throw .countTooLow(expected: 1, got: 0)
        }

        return count
    }
}

// MARK: - `Any` Whitespace

extension Parser.Whitespace {
    /// Parses one or more of any whitespace character.
    ///
    /// Includes space, tab, and all ASCII control characters 0x09-0x0D.
    ///
    /// ## Grammar
    ///
    /// ```
    /// universal = (SPACE | TAB | LF | CR | FF | VT)+
    /// ```
    public struct `Any`: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Whitespace.`Any`: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias ParseOutput = Int
    public typealias Failure = Parser.Constraint.Error

    /// Parses any whitespace and returns the count of bytes consumed.
    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> ParseOutput {
        var count = 0

        while let byte = input.first, Parser.Whitespace.isWhitespace(byte) {
            input.removeFirst()
            count += 1
        }

        guard count > 0 else {
            throw .countTooLow(expected: 1, got: 0)
        }

        return count
    }
}

// MARK: - Skip Whitespace (Infallible)

extension Parser.Whitespace {
    /// Skips zero or more whitespace characters.
    ///
    /// This parser is infallible (never throws) - it simply consumes
    /// whatever whitespace is present and returns void.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Skip any whitespace between tokens
    /// let ws = Parser.Whitespace.Skip()
    /// var input = "   hello"[...].utf8
    /// ws.parse(&input)  // Consumes "   "
    /// // input is now "hello"
    /// ```
    public struct Skip: Sendable {
        /// The kind of whitespace to skip.
        public let kind: Kind

        /// The kind of whitespace to match.
        public enum Kind: Sendable {
            /// Space and tab only.
            case horizontal
            /// Newlines only.
            case vertical
            /// All whitespace.
            case any
        }

        /// Creates a whitespace skipper.
        ///
        /// - Parameter kind: The kind of whitespace to skip. Default `.any`.
        @inlinable
        public init(kind: Kind = .any) {
            self.kind = kind
        }
    }
}

extension Parser.Whitespace.Skip: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias ParseOutput = Void
    public typealias Failure = Never

    @inlinable
    public func parse(_ input: inout Input) -> Void {
        switch kind {
        case .horizontal:
            while let byte = input.first,
                  byte == Parser.Whitespace.space || byte == Parser.Whitespace.tab {
                input.removeFirst()
            }

        case .vertical:
            while let byte = input.first {
                if byte == Parser.Whitespace.lf {
                    input.removeFirst()
                } else if byte == Parser.Whitespace.cr {
                    input.removeFirst()
                    if input.first == Parser.Whitespace.lf {
                        input.removeFirst()
                    }
                } else {
                    break
                }
            }

        case .any:
            while let byte = input.first, Parser.Whitespace.isWhitespace(byte) {
                input.removeFirst()
            }
        }
    }
}

// MARK: - Helper

extension Parser.Whitespace {
    /// Checks if a byte is ASCII whitespace.
    @inlinable
    static func isWhitespace(_ byte: UInt8) -> Bool {
        byte == space ||
        byte == tab ||
        byte == lf ||
        byte == cr ||
        byte == formFeed ||
        byte == verticalTab
    }
}

// MARK: - Convenience Accessors

extension Parser {
    /// Access to whitespace parsers via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.whitespace.Skip()
    /// Parser.whitespace.Horizontal()
    /// ```
    @inlinable
    public static var whitespace: Whitespace.Type { Whitespace.self }
}
