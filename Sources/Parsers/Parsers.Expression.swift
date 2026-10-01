public import Checkpoint

extension Parsers {

    public enum Expression: Sendable {}
}

extension Parsers.Expression {

    public enum Associativity: Sendable {

        case left

        case right

        case none
    }
}

extension Parsers.Expression {

    public struct Operator<Operand, Op: Parsing> {

        public let parser: Op

        public let precedence: Int

        public let associativity: Associativity

        public let apply: (Operand, Operand) -> Operand

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

extension Parsers.Expression {

    public struct PrefixOperator<Operand, Op: Parsing> {

        public let parser: Op

        public let apply: (Operand) -> Operand

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

extension Parsers.Expression {

    public struct PostfixOperator<Operand, Op: Parsing> {

        public let parser: Op

        public let apply: (Operand) -> Operand

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

extension Parsers.Expression {

    public struct Climbing<Atom: Parsing, Op: Parsing>
    where
        Atom.Input == Op.Input,
        Atom.Input: Copyable & Restorable,
        Atom.Input.Checkpoint: Equatable
    {

        public typealias Operand = Atom.Output

        @usableFromInline
        let atom: Atom

        @usableFromInline
        let operators: [Operator<Operand, Op>]

        @usableFromInline
        let prefixOps: [PrefixOperator<Operand, Op>]

        @usableFromInline
        let postfixOps: [PostfixOperator<Operand, Op>]

        @inlinable
        public init(
            atom: Atom,
            operators: [Operator<Operand, Op>],
            prefix: [PrefixOperator<Operand, Op>] = [],
            postfix: [PostfixOperator<Operand, Op>] = []
        ) {
            self.atom = atom

            self.operators = operators.sorted { $0.precedence > $1.precedence }
            self.prefixOps = prefix
            self.postfixOps = postfix
        }
    }
}

extension Parsers.Expression.Climbing: Parsing {
    public typealias Input = Atom.Input
    public typealias Output = Atom.Output
    public typealias Failure = Atom.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        try parseExpression(&input, minPrecedence: 0)
    }

    @inlinable
    package func parseExpression(
        _ input: inout Input,
        minPrecedence: Int
    ) throws(Failure) -> Operand {
        let entry = input.checkpoint

        var lhs = try parsePrimary(&input)

        for postfix in postfixOps {
            let saved = input
            do throws(Op.Failure) {
                _ = try postfix.parser.parse(&input)
                lhs = postfix.apply(lhs)
            } catch {
                input = saved
            }
        }

        while true {

            var matchedOp: Parsers.Expression.Operator<Operand, Op>?
            var opSaved = input

            for op in operators where op.precedence >= minPrecedence {
                let saved = input
                do throws(Op.Failure) {
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

            guard input.checkpoint != entry else {
                input = opSaved
                break
            }

            let nextPrecedence: Int
            switch op.associativity {
            case .left:
                nextPrecedence = op.precedence + 1

            case .right:
                nextPrecedence = op.precedence

            case .none:
                nextPrecedence = op.precedence + 1
            }

            let rhs: Operand
            do throws(Failure) {
                rhs = try parseExpression(&input, minPrecedence: nextPrecedence)
            } catch {

                input = opSaved
                break
            }

            guard input.checkpoint != opSaved.checkpoint else {
                input = opSaved
                break
            }

            lhs = op.apply(lhs, rhs)
        }

        return lhs
    }

    @inlinable
    package func parsePrimary(_ input: inout Input) throws(Failure) -> Operand {

        for prefix in prefixOps {
            let saved = input
            do throws(Op.Failure) {
                _ = try prefix.parser.parse(&input)
            } catch {
                input = saved
                continue
            }
            guard input.checkpoint != saved.checkpoint else {
                input = saved
                continue
            }
            do throws(Failure) {
                return prefix.apply(try parsePrimary(&input))
            } catch {
                input = saved
            }
        }

        return try atom.parse(&input)
    }
}

extension Parsers {

    @inlinable
    public static var expression: Expression.Type { Expression.self }
}
