//
//  Parser.Chain.swift
//  swift-parsing
//
//  Combinators for chaining operators with associativity.
//
//  ## Design
//
//  Chain combinators handle binary operator parsing with proper associativity:
//  - ChainLeft: Left-associative (most common): `1+2+3` → `((1+2)+3)`
//  - ChainRight: Right-associative (exponentiation): `2^3^4` → `(2^(3^4))`
//
//  These are fundamental for expression parsing.
//

extension Parser {
    /// Namespace for chain parsing types.
    public enum Chain: Sendable {}
}

// MARK: - Chain Left

extension Parser.Chain {
    /// Parses a chain of operands with left-associative operators.
    ///
    /// Left-associative means operations group from left to right:
    /// `1 + 2 + 3` = `(1 + 2) + 3`
    ///
    /// ## Grammar
    ///
    /// ```
    /// chainLeft = operand (operator operand)*
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let expr = Parser.Chain.Left(
    ///     operand: integerParser,
    ///     operator: Parser.Literal("+").map { _ in () },
    ///     combine: { $0 + $1 }
    /// )
    ///
    /// var input = "1+2+3"[...].utf8
    /// let result = try expr.parse(&input)  // 6
    /// ```
    public struct Left<Operand: Parser.`Protocol`, Operator: Parser.`Protocol`>
    where
        Operand.Input == Operator.Input,
        Operand.Input: Copyable
    {

        /// The operand parser.
        @usableFromInline
        let operand: Operand

        /// The operator parser.
        @usableFromInline
        let `operator`: Operator

        /// Combines two operands using the parsed operator.
        @usableFromInline
        let combine: (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output

        /// Creates a left-associative chain parser.
        ///
        /// - Parameters:
        ///   - operand: Parser for operands.
        ///   - operator: Parser for operators.
        ///   - combine: Function to combine two operands with an operator.
        @inlinable
        public init(
            operand: Operand,
            operator: Operator,
            combine: @escaping (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output
        ) {
            self.operand = operand
            self.operator = `operator`
            self.combine = combine
        }
    }
}

extension Parser.Chain.Left: Parser.`Protocol` {
    public typealias Input = Operand.Input
    public typealias Output = Operand.Output
    public typealias Failure = Operand.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Parse first operand
        var result = try operand.parse(&input)

        // Parse (operator operand)* with left folding
        while true {
            let saved = input

            // Try operator
            let op: Operator.Output
            do throws(Operator.Failure) {
                op = try `operator`.parse(&input)
            } catch {
                // Restore: the operator may have partially consumed input
                // before failing (e.g. a multi-byte operator).
                input = saved
                break
            }

            // Try next operand
            let rhs: Operand.Output
            do throws(Operand.Failure) {
                rhs = try operand.parse(&input)
            } catch {
                // Restore and break
                input = saved
                break
            }

            // Combine left-associatively
            result = combine(result, op, rhs)
        }

        return result
    }
}

// MARK: - Chain Right

extension Parser.Chain {
    /// Parses a chain of operands with right-associative operators.
    ///
    /// Right-associative means operations group from right to left:
    /// `2 ^ 3 ^ 4` = `2 ^ (3 ^ 4)`
    ///
    /// ## Grammar
    ///
    /// ```
    /// chainRight = operand (operator chainRight)?
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// let power = Parser.Chain.Right(
    ///     operand: integerParser,
    ///     operator: Parser.Literal("^").map { _ in () },
    ///     combine: { pow($0, $1) }
    /// )
    ///
    /// var input = "2^3^4"[...].utf8
    /// let result = try power.parse(&input)  // 2^81 = 2417851639229258349412352
    /// ```
    public struct Right<Operand: Parser.`Protocol`, Operator: Parser.`Protocol`>
    where
        Operand.Input == Operator.Input,
        Operand.Input: Copyable
    {

        /// The operand parser.
        @usableFromInline
        let operand: Operand

        /// The operator parser.
        @usableFromInline
        let `operator`: Operator

        /// Combines two operands using the parsed operator.
        @usableFromInline
        let combine: (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output

        /// Creates a right-associative chain parser.
        ///
        /// - Parameters:
        ///   - operand: Parser for operands.
        ///   - operator: Parser for operators.
        ///   - combine: Function to combine two operands with an operator.
        @inlinable
        public init(
            operand: Operand,
            operator: Operator,
            combine: @escaping (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output
        ) {
            self.operand = operand
            self.operator = `operator`
            self.combine = combine
        }
    }
}

extension Parser.Chain.Right: Parser.`Protocol` {
    public typealias Input = Operand.Input
    public typealias Output = Operand.Output
    public typealias Failure = Operand.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Parse first operand
        let lhs = try operand.parse(&input)

        let saved = input

        // Try operator
        let op: Operator.Output
        do throws(Operator.Failure) {
            op = try `operator`.parse(&input)
        } catch {
            // No operator, return single operand. Restore: the operator may
            // have partially consumed input before failing (e.g. a
            // multi-byte operator).
            input = saved
            return lhs
        }

        // Recursively parse right side (for right associativity)
        let rhs: Operand.Output
        do throws(Operand.Failure) {
            rhs = try parse(&input)
        } catch {
            // Restore and return single operand
            input = saved
            return lhs
        }

        return combine(lhs, op, rhs)
    }
}

// MARK: - Nested Accessor

extension Parser.Chain {
    /// Accessor for creating chain parsers from an operand.
    ///
    /// Obtained via `operand.chain.left(...)` or `operand.chain.right(...)`.
    public struct Access<Operand: Parser.`Protocol`> {

        @usableFromInline
        let operand: Operand

        @usableFromInline
        init(operand: Operand) {
            self.operand = operand
        }

        /// Creates a left-associative chain of the operand with an operator.
        ///
        /// - Parameters:
        ///   - op: The operator parser.
        ///   - combine: Function to combine operands.
        /// - Returns: A left-associative chain parser.
        @inlinable
        public func left<Op: Parser.`Protocol`>(
            _ op: Op,
            combine: @escaping (Operand.Output, Op.Output, Operand.Output) -> Operand.Output
        ) -> Parser.Chain.Left<Operand, Op>
        where Op.Input == Operand.Input, Operand.Input: Copyable {
            Parser.Chain.Left(operand: operand, operator: op, combine: combine)
        }

        /// Creates a right-associative chain of the operand with an operator.
        ///
        /// - Parameters:
        ///   - op: The operator parser.
        ///   - combine: Function to combine operands.
        /// - Returns: A right-associative chain parser.
        @inlinable
        public func right<Op: Parser.`Protocol`>(
            _ op: Op,
            combine: @escaping (Operand.Output, Op.Output, Operand.Output) -> Operand.Output
        ) -> Parser.Chain.Right<Operand, Op>
        where Op.Input == Operand.Input, Operand.Input: Copyable {
            Parser.Chain.Right(operand: operand, operator: op, combine: combine)
        }
    }
}

extension Parser.`Protocol` {
    /// Access chain parsing via `operand.chain.left(...)` or `operand.chain.right(...)`.
    @inlinable
    public var chain: Parser.Chain.Access<Self> {
        Parser.Chain.Access(operand: self)
    }
}
