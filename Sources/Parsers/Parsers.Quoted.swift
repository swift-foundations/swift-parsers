//
//  Parser.Quoted.swift
//  swift-parsing
//
//  Quoted string parsers with escape sequence handling.
//
//  ## Design
//
//  Quoted strings are ubiquitous in programming languages and data formats.
//  This module provides parsers for common quoting styles:
//
//  - Double: "..." with backslash escapes
//  - Single: '...' typically without escapes
//  - Custom: User-defined delimiters and escape handling
//
//  ## Escape Styles
//
//  - Backslash: \n, \t, \\, \" (C/Java/JSON style)
//  - Doubling: "" for literal " (CSV/SQL style)
//

extension Parsers {
    /// Namespace for quoted string parsing types.
    public enum Quoted: Sendable {}
}

// MARK: - Escape Style

extension Parser.Quoted {
    /// Escape sequence handling styles.
    public enum EscapeStyle: Sendable {
        /// Backslash escapes: \n, \t, \\, \", etc.
        case backslash

        /// Character doubling: "" for literal "
        case doubling

        /// No escape handling.
        case none
    }
}

// MARK: - Error Type

extension Parser.Quoted {
    /// Errors from quoted string parsing.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Missing opening delimiter.
        case missingOpenQuote

        /// Missing closing delimiter (unterminated string).
        case unterminatedString

        /// Invalid escape sequence.
        ///
        /// - Parameter sequence: The invalid escape sequence found
        case invalidEscape(sequence: String)

        /// Newline found in string (when not allowed).
        case unexpectedNewline
    }
}

// MARK: - Double Quoted String

extension Parser.Quoted {
    /// Parses double-quoted strings with backslash escapes.
    ///
    /// Handles standard C/JSON escape sequences:
    /// - `\\` → backslash
    /// - `\"` → double quote
    /// - `\n` → newline
    /// - `\r` → carriage return
    /// - `\t` → tab
    /// - `\0` → null
    ///
    /// ## Grammar
    ///
    /// ```
    /// string    = '"' content* '"'
    /// content   = escape | char
    /// escape    = '\' ("\" | '"' | 'n' | 'r' | 't' | '0')
    /// char      = <any except '"', '\', newline>
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let parser = Parser.Quoted.Double()
    /// try parser.parse("\"hello\"")       // "hello"
    /// try parser.parse("\"line\\nbreak\"") // "line\nbreak"
    /// try parser.parse("\"tab\\there\"")   // "tab\there"
    /// ```
    public struct Double: Sendable {
        /// Whether to allow newlines within the string.
        public let allowNewlines: Bool

        /// Creates a double-quoted string parser.
        ///
        /// - Parameter allowNewlines: Allow literal newlines in string. Default `false`.
        @inlinable
        public init(allowNewlines: Bool = false) {
            self.allowNewlines = allowNewlines
        }
    }
}

extension Parser.Quoted.Double: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parser.Quoted.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Expect opening quote
        guard input.first == UInt8(ascii: "\"") else {
            throw .missingOpenQuote
        }
        input.removeFirst()

        var result: [UInt8] = []

        while let byte = input.first {
            if byte == UInt8(ascii: "\"") {
                // Closing quote
                input.removeFirst()
                return String(decoding: result, as: UTF8.self)
            } else if byte == UInt8(ascii: "\\") {
                // Escape sequence
                input.removeFirst()
                guard let escaped = input.first else {
                    throw .unterminatedString
                }
                input.removeFirst()

                switch escaped {
                case UInt8(ascii: "\\"): result.append(UInt8(ascii: "\\"))
                case UInt8(ascii: "\""): result.append(UInt8(ascii: "\""))
                case UInt8(ascii: "n"):  result.append(0x0A) // LF
                case UInt8(ascii: "r"):  result.append(0x0D) // CR
                case UInt8(ascii: "t"):  result.append(0x09) // Tab
                case UInt8(ascii: "0"):  result.append(0x00) // Null
                case UInt8(ascii: "b"):  result.append(0x08) // Backspace
                case UInt8(ascii: "f"):  result.append(0x0C) // Form feed
                default:
                    throw .invalidEscape(sequence: "\\" + String(UnicodeScalar(escaped)))
                }
            } else if byte == 0x0A || byte == 0x0D {
                // Newline
                if allowNewlines {
                    result.append(byte)
                    input.removeFirst()
                } else {
                    throw .unexpectedNewline
                }
            } else {
                result.append(byte)
                input.removeFirst()
            }
        }

        throw .unterminatedString
    }
}

// MARK: - Single Quoted String

extension Parser.Quoted {
    /// Parses single-quoted strings without escape handling.
    ///
    /// Single-quoted strings typically represent literal content without
    /// escape sequences, as in shell scripting and some programming languages.
    ///
    /// ## Grammar
    ///
    /// ```
    /// string = "'" content* "'"
    /// content = <any except "'">
    /// ```
    public struct Single: Sendable {
        /// Whether to allow newlines within the string.
        public let allowNewlines: Bool

        /// Creates a single-quoted string parser.
        ///
        /// - Parameter allowNewlines: Allow literal newlines. Default `false`.
        @inlinable
        public init(allowNewlines: Bool = false) {
            self.allowNewlines = allowNewlines
        }
    }
}

extension Parser.Quoted.Single: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parser.Quoted.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Expect opening quote
        guard input.first == UInt8(ascii: "'") else {
            throw .missingOpenQuote
        }
        input.removeFirst()

        var result: [UInt8] = []

        while let byte = input.first {
            if byte == UInt8(ascii: "'") {
                // Closing quote
                input.removeFirst()
                return String(decoding: result, as: UTF8.self)
            } else if byte == 0x0A || byte == 0x0D {
                // Newline
                if allowNewlines {
                    result.append(byte)
                    input.removeFirst()
                } else {
                    throw .unexpectedNewline
                }
            } else {
                result.append(byte)
                input.removeFirst()
            }
        }

        throw .unterminatedString
    }
}

// MARK: - CSV-Style (Doubling Escapes)

extension Parser.Quoted {
    /// Parses quoted strings with character doubling for escapes.
    ///
    /// This is the CSV and SQL style where `""` represents a literal `"`.
    ///
    /// ## Grammar
    ///
    /// ```
    /// string  = '"' content* '"'
    /// content = '""' | <any except '"'>
    /// ```
    public struct Doubling: Sendable {
        /// The quote character (typically `"`).
        public let quote: UInt8

        /// Creates a doubling-escape string parser.
        ///
        /// - Parameter quote: The quote character. Default `"`.
        @inlinable
        public init(quote: UInt8 = UInt8(ascii: "\"")) {
            self.quote = quote
        }
    }
}

extension Parser.Quoted.Doubling: Parser.Parser {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parser.Quoted.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Expect opening quote
        guard input.first == quote else {
            throw .missingOpenQuote
        }
        input.removeFirst()

        var result: [UInt8] = []

        while let byte = input.first {
            if byte == quote {
                input.removeFirst()
                // Check for doubled quote
                if input.first == quote {
                    result.append(quote)
                    input.removeFirst()
                } else {
                    // Single quote = closing
                    return String(decoding: result, as: UTF8.self)
                }
            } else {
                result.append(byte)
                input.removeFirst()
            }
        }

        throw .unterminatedString
    }
}

// MARK: - Convenience Accessors

extension Parsers {
    /// Access to quoted string parsers via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.quoted.Double()
    /// Parser.quoted.Single()
    /// Parser.quoted.Doubling()
    /// ```
    @inlinable
    public static var quoted: Quoted.Type { Quoted.self }
}
