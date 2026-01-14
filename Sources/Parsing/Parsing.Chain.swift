//
//  Parsing.Chain.swift
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

extension Parsing {
    /// Namespace for chain parsing types.
    public enum Chain: Sendable {}
}

// MARK: - Chain Left

extension Parsing.Chain {
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
    /// let expr = Parsing.Chain.Left(
    ///     operand: integerParser,
    ///     operator: Parsing.Literal("+").map { _ in () },
    ///     combine: { $0 + $1 }
    /// )
    ///
    /// var input = "1+2+3"[...].utf8
    /// let result = try expr.parse(&input)  // 6
    /// ```
    public struct Left<Operand: Parsing.Parser, Operator: Parsing.Parser>: Sendable
    where Operand: Sendable, Operator: Sendable,
          Operand.Input == Operator.Input,
          Operand.Output: Sendable {

        /// The operand parser.
        @usableFromInline
        let operand: Operand

        /// The operator parser.
        @usableFromInline
        let `operator`: Operator

        /// Combines two operands using the parsed operator.
        @usableFromInline
        let combine: @Sendable (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output

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
            combine: @escaping @Sendable (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output
        ) {
            self.operand = operand
            self.operator = `operator`
            self.combine = combine
        }
    }
}

extension Parsing.Chain.Left: Parsing.Parser
where Operand.Input: Parsing.Input {
    public typealias Input = Operand.Input
    public typealias Output = Operand.Output
    public typealias Failure = Operand.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Parse first operand
        var result = try operand.parse(&input)

        // Parse (operator operand)* with left folding
        while true {
            let checkpoint = input.checkpoint

            // Try operator
            let op: Operator.Output
            do {
                op = try `operator`.parse(&input)
            } catch {
                break
            }

            // Try next operand
            let rhs: Operand.Output
            do {
                rhs = try operand.parse(&input)
            } catch {
                // Restore and break
                input.restore(to: checkpoint)
                break
            }

            // Combine left-associatively
            result = combine(result, op, rhs)
        }

        return result
    }
}

// MARK: - Chain Right

extension Parsing.Chain {
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
    /// let power = Parsing.Chain.Right(
    ///     operand: integerParser,
    ///     operator: Parsing.Literal("^").map { _ in () },
    ///     combine: { pow($0, $1) }
    /// )
    ///
    /// var input = "2^3^4"[...].utf8
    /// let result = try power.parse(&input)  // 2^81 = 2417851639229258349412352
    /// ```
    public struct Right<Operand: Parsing.Parser, Operator: Parsing.Parser>: Sendable
    where Operand: Sendable, Operator: Sendable,
          Operand.Input == Operator.Input,
          Operand.Input: Parsing.Input,
          Operand.Output: Sendable {

        /// The operand parser.
        @usableFromInline
        let operand: Operand

        /// The operator parser.
        @usableFromInline
        let `operator`: Operator

        /// Combines two operands using the parsed operator.
        @usableFromInline
        let combine: @Sendable (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output

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
            combine: @escaping @Sendable (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output
        ) {
            self.operand = operand
            self.operator = `operator`
            self.combine = combine
        }
    }
}

extension Parsing.Chain.Right: Parsing.Parser {
    public typealias Input = Operand.Input
    public typealias Output = Operand.Output
    public typealias Failure = Operand.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Parse first operand
        let lhs = try operand.parse(&input)

        let checkpoint = input.checkpoint

        // Try operator
        let op: Operator.Output
        do {
            op = try `operator`.parse(&input)
        } catch {
            // No operator, return single operand
            return lhs
        }

        // Recursively parse right side (for right associativity)
        let rhs: Operand.Output
        do {
            rhs = try parse(&input)
        } catch {
            // Restore and return single operand
            input.restore(to: checkpoint)
            return lhs
        }

        return combine(lhs, op, rhs)
    }
}

// MARK: - Parser Extensions

extension Parsing.Parser where Self: Sendable, Output: Sendable {
    /// Creates a left-associative chain of this operand with an operator.
    ///
    /// - Parameters:
    ///   - op: The operator parser.
    ///   - combine: Function to combine operands.
    /// - Returns: A left-associative chain parser.
    @inlinable
    public func chainLeft<Op: Parsing.Parser>(
        _ op: Op,
        combine: @escaping @Sendable (Output, Op.Output, Output) -> Output
    ) -> Parsing.Chain.Left<Self, Op>
    where Op.Input == Input, Op: Sendable {
        Parsing.Chain.Left<Self, Op>(operand: self, operator: op, combine: combine)
    }

    /// Creates a right-associative chain of this operand with an operator.
    ///
    /// - Parameters:
    ///   - op: The operator parser.
    ///   - combine: Function to combine operands.
    /// - Returns: A right-associative chain parser.
    @inlinable
    public func chainRight<Op: Parsing.Parser>(
        _ op: Op,
        combine: @escaping @Sendable (Output, Op.Output, Output) -> Output
    ) -> Parsing.Chain.Right<Self, Op>
    where Op.Input == Input, Op: Sendable, Input: Parsing.Input {
        Parsing.Chain.Right<Self, Op>(operand: self, operator: op, combine: combine)
    }
}
