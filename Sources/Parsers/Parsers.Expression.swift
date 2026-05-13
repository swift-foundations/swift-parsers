//
//  Parser.Expression.swift
//  swift-parsing
//
//  Expression parsing with precedence climbing.
//
//  ## Design
//
//  Expression parsing handles operators with different precedence levels
//  and associativity. This module implements the "precedence climbing"
//  algorithm, which is efficient and handles:
//
//  - Multiple precedence levels
//  - Left/right/non-associative operators
//  - Prefix operators (unary minus, negation)
//  - Postfix operators (factorial, optional chaining)
//
//  ## Algorithm
//
//  Precedence climbing parses expressions by:
//  1. Parse an atom (literal, identifier, parenthesized expression)
//  2. While next operator has precedence >= current level:
//     a. Parse the operator
//     b. Recursively parse RHS at appropriate precedence
//     c. Combine LHS and RHS
//
//  This naturally handles precedence and associativity without
//  needing separate grammar rules for each level.
//

extension Parser {
    /// Namespace for expression parsing types.
    public enum Expression: Sendable {}
}

// MARK: - Associativity

extension Parser.Expression {
    /// Operator associativity.
    public enum Associativity: Sendable {
        /// Left-to-right: `1-2-3` = `(1-2)-3`
        case left
        /// Right-to-left: `2^3^4` = `2^(3^4)`
        case right
        /// Non-associative: `1<2<3` is an error
        case none
    }
}

// MARK: - Operator

extension Parser.Expression {
    /// Defines an infix operator with precedence and associativity.
    ///
    /// All operators in a `Climbing` parser must use the same `Op` parser type.
    public struct Operator<Operand, Op: Parser.`Protocol`> {
        /// The operator parser.
        public let parser: Op

        /// Precedence level (higher = binds tighter).
        public let precedence: Int

        /// Operator associativity.
        public let associativity: Associativity

        /// Combines two operands.
        public let apply: (Operand, Operand) -> Operand

        /// Creates an operator definition.
        ///
        /// - Parameters:
        ///   - parser: Parser matching this operator.
        ///   - precedence: Precedence level.
        ///   - associativity: Operator associativity.
        ///   - apply: Function combining operands.
        @inlinable
        public init(
            parser: Op,
            precedence: Int,
            associativity: Associativity,
            apply: @escaping (Operand, Operand) -> Operand
        ) {
            self.parser = parser
            self.precedence = precedence
            self.associativity = associativity
            self.apply = apply
        }
    }
}

// MARK: - Prefix Operator

extension Parser.Expression {
    /// Defines a prefix (unary) operator.
    public struct PrefixOperator<Operand, Op: Parser.`Protocol`> {
        /// The operator parser.
        public let parser: Op

        /// Applies the operator to an operand.
        public let apply: (Operand) -> Operand

        /// Creates a prefix operator definition.
        ///
        /// - Parameters:
        ///   - parser: Parser matching this operator.
        ///   - apply: Function applying the operator.
        @inlinable
        public init(
            parser: Op,
            apply: @escaping (Operand) -> Operand
        ) {
            self.parser = parser
            self.apply = apply
        }
    }
}

// MARK: - Postfix Operator

extension Parser.Expression {
    /// Defines a postfix (unary) operator.
    public struct PostfixOperator<Operand, Op: Parser.`Protocol`> {
        /// The operator parser.
        public let parser: Op

        /// Applies the operator to an operand.
        public let apply: (Operand) -> Operand

        /// Creates a postfix operator definition.
        ///
        /// - Parameters:
        ///   - parser: Parser matching this operator.
        ///   - apply: Function applying the operator.
        @inlinable
        public init(
            parser: Op,
            apply: @escaping (Operand) -> Operand
        ) {
            self.parser = parser
            self.apply = apply
        }
    }
}

// MARK: - Climbing Parser

extension Parser.Expression {
    /// Precedence climbing expression parser.
    ///
    /// Parses expressions with multiple operators at different precedence
    /// levels, respecting associativity rules. All operators must use the
    /// same parser type `Op`.
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Simple arithmetic: 1 + 2 * 3 = 7 (not 9)
    /// let expr = Parser.Expression.Climbing(
    ///     atom: integerParser,
    ///     operators: [
    ///         Operator(parser: Literal("+"), precedence: 1, associativity: .left) { $0 + $1 },
    ///         Operator(parser: Literal("*"), precedence: 2, associativity: .left) { $0 * $1 },
    ///     ]
    /// )
    /// ```
    public struct Climbing<Atom: Parser.`Protocol`, Op: Parser.`Protocol`>
    where Atom.Input == Op.Input,
          Atom.Input: Copyable {

        public typealias Operand = Atom.Output

        /// The atom parser.
        @usableFromInline
        let atom: Atom

        /// Infix operators (sorted by precedence descending).
        @usableFromInline
        let operators: [Operator<Operand, Op>]

        /// Prefix operators.
        @usableFromInline
        let prefixOps: [PrefixOperator<Operand, Op>]

        /// Postfix operators.
        @usableFromInline
        let postfixOps: [PostfixOperator<Operand, Op>]

        /// Creates a precedence climbing parser.
        ///
        /// - Parameters:
        ///   - atom: Parser for atomic expressions.
        ///   - operators: Infix operator definitions.
        ///   - prefix: Prefix operator definitions.
        ///   - postfix: Postfix operator definitions.
        @inlinable
        public init(
            atom: Atom,
            operators: [Operator<Operand, Op>],
            prefix: [PrefixOperator<Operand, Op>] = [],
            postfix: [PostfixOperator<Operand, Op>] = []
        ) {
            self.atom = atom
            // Sort operators by precedence (descending) for faster matching
            self.operators = operators.sorted { $0.precedence > $1.precedence }
            self.prefixOps = prefix
            self.postfixOps = postfix
        }
    }
}

extension Parser.Expression.Climbing: Parser.`Protocol` {
    public typealias Input = Atom.Input
    public typealias Output = Atom.Output
    public typealias Failure = Atom.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        try parseExpression(&input, minPrecedence: 0)
    }

    @inlinable
    func parseExpression(
        _ input: inout Input,
        minPrecedence: Int
    ) throws(Failure) -> Operand {
        var lhs = try parsePrimary(&input)

        // Apply postfix operators
        for postfix in postfixOps {
            let saved = input
            do {
                _ = try postfix.parser.parse(&input)
                lhs = postfix.apply(lhs)
            } catch {
                input = saved
            }
        }

        // Precedence climbing loop
        while true {
            // Find matching operator at this precedence level
            var matchedOp: Parser.Expression.Operator<Operand, Op>?
            var opSaved = input

            for op in operators where op.precedence >= minPrecedence {
                let saved = input
                do {
                    _ = try op.parser.parse(&input)
                    matchedOp = op
                    opSaved = saved
                    break
                } catch {
                    input = saved
                }
            }

            guard let op = matchedOp else {
                break
            }

            // Determine next precedence for right side
            let nextPrecedence: Int
            switch op.associativity {
            case .left:
                nextPrecedence = op.precedence + 1
            case .right:
                nextPrecedence = op.precedence
            case .none:
                nextPrecedence = op.precedence + 1
            }

            // Parse right-hand side
            let rhs: Operand
            do {
                rhs = try parseExpression(&input, minPrecedence: nextPrecedence)
            } catch {
                // Restore to before operator
                input = opSaved
                break
            }

            lhs = op.apply(lhs, rhs)
        }

        return lhs
    }

    @inlinable
    func parsePrimary(_ input: inout Input) throws(Failure) -> Operand {
        // Try prefix operators
        for prefix in prefixOps {
            let saved = input
            do {
                _ = try prefix.parser.parse(&input)
                let operand = try parsePrimary(&input)
                return prefix.apply(operand)
            } catch {
                input = saved
            }
        }

        // Parse atom
        return try atom.parse(&input)
    }
}

// MARK: - Convenience Accessors

extension Parser {
    /// Access to expression parsing types via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.expression.Climbing(atom: ..., operators: [...])
    /// Parser.expression.Operator(parser: ..., precedence: 1, associativity: .left) { $0 + $1 }
    /// ```
    @inlinable
    public static var expression: Expression.Type { Expression.self }
}
