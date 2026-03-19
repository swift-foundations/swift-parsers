//
//  Parser.Separated.swift
//  swift-parsing
//
//  Combinator for parsing values separated by delimiters.
//
//  ## Design
//
//  `Separated` parses a sequence of values separated by a delimiter.
//  Common use cases include:
//  - CSV fields: `a,b,c`
//  - Array elements: `[1, 2, 3]`
//  - Function arguments: `f(x, y, z)`
//
//  Options include:
//  - Minimum/maximum count constraints
//  - Allowing trailing separators
//  - Allowing empty elements
//

extension Parser {
    /// A parser that matches values separated by a delimiter.
    ///
    /// Parses zero or more occurrences of `Element` separated by `Separator`.
    ///
    /// ## Grammar
    ///
    /// ```
    /// separated = element (separator element)* [separator]?  // if allowTrailing
    /// separated = element (separator element)*               // otherwise
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let csv = Parser.Separated(
    ///     element: Parser.Prefix.While { $0 != UInt8(ascii: ",") && $0 != 0x0A },
    ///     separator: Parser.Literal(",")
    /// )
    ///
    /// var input = "a,b,c"[...].utf8
    /// let values = try csv.parse(&input)  // ["a", "b", "c"]
    /// ```
    public struct Separated<Element: Parser.`Protocol`, Separator: Parser.`Protocol`>: Sendable
    where Element: Sendable, Separator: Sendable,
          Element.Input == Separator.Input,
          Element.Input: Copyable {

        /// The element parser.
        @usableFromInline
        let element: Element

        /// The separator parser.
        @usableFromInline
        let separator: Separator

        /// Minimum required element count.
        public let minCount: Int

        /// Maximum allowed element count (nil = unlimited).
        public let maxCount: Int?

        /// Whether to allow a trailing separator.
        public let allowTrailing: Bool

        /// Creates a separated parser.
        ///
        /// - Parameters:
        ///   - element: Parser for individual elements.
        ///   - separator: Parser for delimiters between elements.
        ///   - minCount: Minimum elements required. Default `0`.
        ///   - maxCount: Maximum elements allowed. Default `nil` (unlimited).
        ///   - allowTrailing: Allow trailing separator. Default `false`.
        @inlinable
        public init(
            element: Element,
            separator: Separator,
            minCount: Int = 0,
            maxCount: Int? = nil,
            allowTrailing: Bool = false
        ) {
            self.element = element
            self.separator = separator
            self.minCount = minCount
            self.maxCount = maxCount
            self.allowTrailing = allowTrailing
        }
    }
}

extension Parser.Separated: Parser.`Protocol` {
    public typealias Input = Element.Input
    public typealias Output = [Element.Output]
    public typealias Failure = Either<
        Parser.Constraint.Error,
        Element.Failure
    >

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var results: [Element.Output] = []

        // Try to parse first element
        do {
            let first = try element.parse(&input)
            results.append(first)
        } catch {
            // No first element
            if minCount > 0 {
                throw .left(.countTooLow(expected: minCount, got: 0))
            }
            return results
        }

        // Parse separator + element pairs
        while maxCount.map({ results.count < $0 }) ?? true {
            let saved = input

            // Try separator
            do {
                _ = try separator.parse(&input)
            } catch {
                // No separator, done
                break
            }

            // Try element after separator
            do {
                let next = try element.parse(&input)
                results.append(next)
            } catch {
                // Separator but no element
                if allowTrailing {
                    // Trailing separator is OK
                    break
                } else {
                    // Restore to before separator and fail
                    input = saved
                    break
                }
            }
        }

        // Check minimum count
        if results.count < minCount {
            throw .left(.countTooLow(expected: minCount, got: results.count))
        }

        return results
    }
}

// MARK: - Parser Extension

extension Parser.`Protocol` {
    /// Creates a parser that matches this parser separated by a delimiter.
    ///
    /// - Parameters:
    ///   - separator: The separator parser.
    ///   - allowTrailing: Allow trailing separator. Default `false`.
    /// - Returns: A parser matching separated values.
    @inlinable
    public func separated<S: Parser.`Protocol`>(
        by separator: S,
        allowTrailing: Bool = false
    ) -> Parser.Separated<Self, S>
    where S.Input == Input, S: Sendable, Self: Sendable, Input: Copyable {
        Parser.Separated(
            element: self,
            separator: separator,
            allowTrailing: allowTrailing
        )
    }
}
