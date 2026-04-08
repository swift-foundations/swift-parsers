//
//  Parser.Comment.swift
//  swift-parsing
//
//  Comment parsers for line and block comments.
//
//  ## Design
//
//  Comments are essential for parsing programming languages. This module
//  provides parsers for common comment styles:
//
//  - Line: Single-line comments (// ..., # ..., -- ...)
//  - Block: Multi-line comments (/* ... */, <!-- ... -->)
//
//  Block comments optionally support nesting for languages like Swift
//  that allow /* /* nested */ */.
//

extension Parser {
    /// Namespace for comment parsing types.
    public enum Comment: Sendable {}
}

// MARK: - Line Comment

extension Parser.Comment {
    /// Parses line comments from prefix to end of line.
    ///
    /// Line comments start with a prefix (e.g., //, #) and continue
    /// to the end of the line. The newline itself is NOT consumed.
    ///
    /// ## Grammar
    ///
    /// ```
    /// line_comment = prefix <any>* (NEWLINE | EOF)
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // C/C++/Swift style
    /// let cpp = Parser.Comment.Line(prefix: "//")
    ///
    /// // Shell/Python style
    /// let shell = Parser.Comment.Line(prefix: "#")
    ///
    /// // SQL style
    /// let sql = Parser.Comment.Line(prefix: "--")
    /// ```
    public struct Line: Sendable {
        /// The comment prefix (e.g., "//", "#").
        @usableFromInline
        let prefixBytes: [UInt8]

        /// Creates a line comment parser.
        ///
        /// - Parameter prefix: The comment start prefix.
        @inlinable
        public init(prefix: StaticString = "//") {
            self.prefixBytes = prefix.withUTF8Buffer { [UInt8]($0) }
        }
    }
}

extension Parser.Comment.Line: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Match prefix
        var inputCopy = input
        for expected in prefixBytes {
            guard inputCopy.first == expected else {
                throw .predicateFailed(description: "line comment prefix")
            }
            inputCopy.removeFirst()
        }
        input = inputCopy

        // Consume until newline or EOF
        var content: [UInt8] = []
        while let byte = input.first, byte != .ascii.lf, byte != .ascii.cr {
            content.append(byte)
            input.removeFirst()
        }

        return String(decoding: content, as: UTF8.self)
    }
}

// MARK: - Block Comment

extension Parser.Comment {
    /// Parses block comments with open/close delimiters.
    ///
    /// Block comments span multiple lines, bounded by open and close
    /// delimiters. Optionally supports nesting for languages like Swift.
    ///
    /// ## Grammar
    ///
    /// ```
    /// block_comment = open content* close
    /// content       = block_comment | <any>  // if nestable
    /// content       = <any>                  // if not nestable
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // C/C++/Java style (non-nesting)
    /// let c = Parser.Comment.Block(open: "/*", close: "*/")
    ///
    /// // Swift style (nesting)
    /// let swift = Parser.Comment.Block(open: "/*", close: "*/", nestable: true)
    ///
    /// // HTML style
    /// let html = Parser.Comment.Block(open: "<!--", close: "-->")
    /// ```
    public struct Block: Sendable {
        /// The opening delimiter bytes.
        @usableFromInline
        let openBytes: [UInt8]

        /// The closing delimiter bytes.
        @usableFromInline
        let closeBytes: [UInt8]

        /// Whether nested comments are allowed.
        public let nestable: Bool

        /// Creates a block comment parser.
        ///
        /// - Parameters:
        ///   - open: The opening delimiter.
        ///   - close: The closing delimiter.
        ///   - nestable: Allow nested comments. Default `false`.
        @inlinable
        public init(
            open: StaticString = "/*",
            close: StaticString = "*/",
            nestable: Bool = false
        ) {
            self.openBytes = open.withUTF8Buffer { [UInt8]($0) }
            self.closeBytes = close.withUTF8Buffer { [UInt8]($0) }
            self.nestable = nestable
        }
    }
}

extension Parser.Comment.Block {
    /// Errors from block comment parsing.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// Missing opening delimiter.
        case missingOpen

        /// Missing closing delimiter (unterminated comment).
        case unterminatedComment
    }
}

extension Parser.Comment.Block: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parser.Comment.Block.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Match opening delimiter
        var inputCopy = input
        for expected in openBytes {
            guard inputCopy.first == expected else {
                throw .missingOpen
            }
            inputCopy.removeFirst()
        }
        input = inputCopy

        var content: [UInt8] = []
        var depth = 1

        while !input.isEmpty {
            // Check for close delimiter
            if matches(closeBytes, in: input) {
                depth -= 1
                if depth == 0 {
                    // Consume close delimiter
                    for _ in closeBytes {
                        input.removeFirst()
                    }
                    return String(decoding: content, as: UTF8.self)
                } else {
                    // Nested close, add to content
                    for byte in closeBytes {
                        content.append(byte)
                        input.removeFirst()
                    }
                }
            }
            // Check for nested open (if nestable)
            else if nestable && matches(openBytes, in: input) {
                depth += 1
                for byte in openBytes {
                    content.append(byte)
                    input.removeFirst()
                }
            } else {
                content.append(input.first!)
                input.removeFirst()
            }
        }

        throw .unterminatedComment
    }

    @inlinable
    func matches(_ bytes: [UInt8], in input: Input) -> Bool {
        var check = input
        for expected in bytes {
            guard check.first == expected else { return false }
            check.removeFirst()
        }
        return true
    }
}

// MARK: - Convenience Accessors

extension Parser {
    /// Access to comment parsers via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.comment.Line(prefix: "//")
    /// Parser.comment.Block(open: "/*", close: "*/")
    /// ```
    @inlinable
    public static var comment: Comment.Type { Comment.self }
}
