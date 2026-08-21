extension Parser {

    public enum Chain: Sendable {}
}

extension Parser.Chain {

    public struct Left<Operand: Parser.`Protocol`, Operator: Parser.`Protocol`>
    where
        Operand.Input == Operator.Input,
        Operand.Input: Copyable
    {

        @usableFromInline
        let operand: Operand

        @usableFromInline
        let `operator`: Operator

        @usableFromInline
        let combine: (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output

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

        var result = try operand.parse(&input)

        while true {
            let saved = input

            let op: Operator.Output
            do throws(Operator.Failure) {
                op = try `operator`.parse(&input)
            } catch {

                input = saved
                break
            }

            let rhs: Operand.Output
            do throws(Operand.Failure) {
                rhs = try operand.parse(&input)
            } catch {

                input = saved
                break
            }

            result = combine(result, op, rhs)
        }

        return result
    }
}

extension Parser.Chain {

    public struct Right<Operand: Parser.`Protocol`, Operator: Parser.`Protocol`>
    where
        Operand.Input == Operator.Input,
        Operand.Input: Copyable
    {

        @usableFromInline
        let operand: Operand

        @usableFromInline
        let `operator`: Operator

        @usableFromInline
        let combine: (Operand.Output, Operator.Output, Operand.Output) -> Operand.Output

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

        let lhs = try operand.parse(&input)

        let saved = input

        let op: Operator.Output
        do throws(Operator.Failure) {
            op = try `operator`.parse(&input)
        } catch {

            input = saved
            return lhs
        }

        let rhs: Operand.Output
        do throws(Operand.Failure) {
            rhs = try parse(&input)
        } catch {

            input = saved
            return lhs
        }

        return combine(lhs, op, rhs)
    }
}

extension Parser.Chain {

    public struct Access<Operand: Parser.`Protocol`> {

        @usableFromInline
        let operand: Operand

        @usableFromInline
        init(operand: Operand) {
            self.operand = operand
        }

        @inlinable
        public func left<Op: Parser.`Protocol`>(
            _ op: Op,
            combine: @escaping (Operand.Output, Op.Output, Operand.Output) -> Operand.Output
        ) -> Parser.Chain.Left<Operand, Op>
        where Op.Input == Operand.Input, Operand.Input: Copyable {
            Parser.Chain.Left(operand: operand, operator: op, combine: combine)
        }

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

    @inlinable
    public var chain: Parser.Chain.Access<Self> {
        Parser.Chain.Access(operand: self)
    }
}
