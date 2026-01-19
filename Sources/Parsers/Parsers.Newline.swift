//
//  Parser.Newline.swift
//  swift-parsing
//
//  Newline parsers for line-oriented parsing.
//
//  ## Design
//
//  Newlines are surprisingly complex due to platform differences:
//  - Unix/Linux/macOS: LF (\n)
//  - Classic Mac: CR (\r)
//  - Windows: CRLF (\r\n)
//
//  This module provides parsers for each style and a universal parser.
//

extension Parsers {
    /// Namespace for newline parsing types.
    public enum Newline: Sendable {}
}

// MARK: - LF (Unix)

extension Parser.Newline {
    /// Parses Unix-style newline: LF (\n).
    ///
    /// This is the standard for Unix, Linux, and modern macOS.
    public struct LF: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.LF: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == 0x0A else {
            throw .predicateFailed(description: "LF (\\n)")
        }
        input.removeFirst()
    }
}

// MARK: - CR (Classic Mac)

extension Parser.Newline {
    /// Parses Classic Mac newline: CR (\r).
    ///
    /// Note: This is rarely used in modern systems but may appear in
    /// legacy files or specific protocols.
    public struct CR: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.CR: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == 0x0D else {
            throw .predicateFailed(description: "CR (\\r)")
        }
        input.removeFirst()
    }
}

// MARK: - CRLF (Windows)

extension Parser.Newline {
    /// Parses Windows-style newline: CRLF (\r\n).
    ///
    /// This is the standard for Windows and many network protocols (HTTP, SMTP).
    public struct CRLF: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.CRLF: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == 0x0D else {
            throw .predicateFailed(description: "CRLF (\\r\\n)")
        }

        var copy = input
        copy.removeFirst()

        guard copy.first == 0x0A else {
            throw .predicateFailed(description: "CRLF (\\r\\n)")
        }

        input = copy
        input.removeFirst()
    }
}

// MARK: - `Any` Newline

extension Parser.Newline {
    /// Parses any newline style: CRLF, LF, or CR.
    ///
    /// Attempts to match in order: CRLF, LF, CR.
    /// This ensures CRLF is not partially matched as CR.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let nl = Parser.Newline.`Any`()
    /// // Matches "\r\n", "\n", or "\r"
    /// ```
    public struct `Any`: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.`Any`: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Void {
        guard let first = input.first else {
            throw .predicateFailed(description: "newline")
        }

        if first == 0x0D {
            // Could be CR or CRLF
            input.removeFirst()
            if input.first == 0x0A {
                input.removeFirst()  // CRLF
            }
            // else just CR
        } else if first == 0x0A {
            input.removeFirst()  // LF
        } else {
            throw .predicateFailed(description: "newline")
        }
    }
}

// MARK: - Line (Until Newline)

extension Parser.Newline {
    /// Parses content up to (but not including) a newline.
    ///
    /// Does NOT consume the newline itself. Use `Any` after if needed.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let line = Parser.Newline.Line()
    /// var input = "hello world\nmore"[...].utf8
    /// let content = try line.parse(&input)  // "hello world"
    /// // input is now "\nmore"
    /// ```
    public struct Line: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.Line: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Never

    /// Parses until a newline and returns the byte count consumed.
    @inlinable
    public func parse(_ input: inout Input) -> Output {
        var count = 0

        while let byte = input.first, byte != 0x0A, byte != 0x0D {
            input.removeFirst()
            count += 1
        }

        return count
    }
}

// MARK: - Convenience Accessors

extension Parsers {
    /// Access to newline parsers via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.newline.`Any`()
    /// Parser.newline.CRLF()
    /// Parser.newline.Line()
    /// ```
    @inlinable
    public static var newline: Newline.Type { Newline.self }
}
