//
//  Parser.Between.swift
//  swift-parsing
//
//  Combinator for parsing content between delimiters.
//
//  ## Design
//
//  `Between` parses content surrounded by open and close delimiters.
//  Common use cases include:
//  - Parenthesized expressions: `(expr)`
//  - Bracketed arrays: `[1, 2, 3]`
//  - Braced blocks: `{ ... }`
//  - XML/HTML tags: `<tag>content</tag>`
//

extension Parser {
    /// A parser that matches content between open and close delimiters.
    ///
    /// Parses `open`, then `content`, then `close`, returning the content.
    ///
    /// ## Grammar
    ///
    /// ```
    /// between = open content close
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let parens = Parser.Between(
    ///     open: Parser.Literal("("),
    ///     content: integerParser,
    ///     close: Parser.Literal(")")
    /// )
    ///
    /// var input = "(42)"[...].utf8
    /// let value = try parens.parse(&input)  // 42
    /// ```
    public struct Between<Open: Parser.`Protocol`, Content: Parser.`Protocol`, Close: Parser.`Protocol`>: Sendable
    where Open: Sendable, Content: Sendable, Close: Sendable,
          Open.Input == Content.Input, Content.Input == Close.Input {

        /// The opening delimiter parser.
        @usableFromInline
        let open: Open

        /// The content parser.
        @usableFromInline
        let content: Content

        /// The closing delimiter parser.
        @usableFromInline
        let close: Close

        /// Creates a between parser.
        ///
        /// - Parameters:
        ///   - open: Parser for opening delimiter.
        ///   - content: Parser for inner content.
        ///   - close: Parser for closing delimiter.
        @inlinable
        public init(
            open: Open,
            content: Content,
            close: Close
        ) {
            self.open = open
            self.content = content
            self.close = close
        }
    }
}

extension Parser.Between: Parser.`Protocol` {
    public typealias Input = Content.Input
    public typealias Output = Content.Output
    public typealias Failure = Either<
        Either<Open.Failure, Content.Failure>,
        Close.Failure
    >

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Parse open
        do {
            _ = try open.parse(&input)
        } catch let error {
            throw .left(.left(error))
        }

        // Parse content
        let result: Content.Output
        do {
            result = try content.parse(&input)
        } catch let error {
            throw .left(.right(error))
        }

        // Parse close
        do {
            _ = try close.parse(&input)
        } catch let error {
            throw .right(error)
        }

        return result
    }
}

// MARK: - Parser Extension

extension Parser.`Protocol` {
    /// Creates a parser that matches this parser between delimiters.
    ///
    /// - Parameters:
    ///   - open: The opening delimiter parser.
    ///   - close: The closing delimiter parser.
    /// - Returns: A parser matching content between delimiters.
    @inlinable
    public func between<Open: Parser.`Protocol`, Close: Parser.`Protocol`>(
        _ open: Open,
        _ close: Close
    ) -> Parser.Between<Open, Self, Close>
    where Open.Input == Input, Close.Input == Input,
          Open: Sendable, Close: Sendable, Self: Sendable {
        Parser.Between(open: open, content: self, close: close)
    }
}

// MARK: - Surrounded (Same Delimiter)

extension Parser {
    /// A parser that matches content surrounded by the same delimiter.
    ///
    /// Convenience for when open and close delimiters are identical.
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let backticked = Parser.Surrounded(
    ///     delimiter: Parser.Literal("`"),
    ///     content: identifierParser
    /// )
    ///
    /// var input = "`foo`"[...].utf8
    /// let value = try backticked.parse(&input)  // "foo"
    /// ```
    public struct Surrounded<Delimiter: Parser.`Protocol`, Content: Parser.`Protocol`>: Sendable
    where Delimiter: Sendable, Content: Sendable,
          Delimiter.Input == Content.Input {

        /// The delimiter parser (used for both open and close).
        @usableFromInline
        let delimiter: Delimiter

        /// The content parser.
        @usableFromInline
        let content: Content

        /// Creates a surrounded parser.
        ///
        /// - Parameters:
        ///   - delimiter: Parser for both open and close delimiter.
        ///   - content: Parser for inner content.
        @inlinable
        public init(
            delimiter: Delimiter,
            content: Content
        ) {
            self.delimiter = delimiter
            self.content = content
        }
    }
}

extension Parser.Surrounded: Parser.`Protocol` {
    public typealias Input = Content.Input
    public typealias Output = Content.Output
    public typealias Failure = Either<
        Either<Delimiter.Failure, Content.Failure>,
        Delimiter.Failure
    >

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Parse open
        do {
            _ = try delimiter.parse(&input)
        } catch let error {
            throw .left(.left(error))
        }

        // Parse content
        let result: Content.Output
        do {
            result = try content.parse(&input)
        } catch let error {
            throw .left(.right(error))
        }

        // Parse close
        do {
            _ = try delimiter.parse(&input)
        } catch let error {
            throw .right(error)
        }

        return result
    }
}

// MARK: - Parser Extension for Surrounded

extension Parser.`Protocol` {
    /// Creates a parser that matches this parser surrounded by a delimiter.
    ///
    /// - Parameter delimiter: The delimiter parser (same for open and close).
    /// - Returns: A parser matching content between identical delimiters.
    @inlinable
    public func surrounded<D: Parser.`Protocol`>(
        by delimiter: D
    ) -> Parser.Surrounded<D, Self>
    where D.Input == Input, D: Sendable, Self: Sendable {
        Parser.Surrounded(delimiter: delimiter, content: self)
    }
}
