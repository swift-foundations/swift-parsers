public import Checkpoint

extension Parsers {

    public enum Chain: Sendable {}
}

extension Parsers.Chain {

    public struct Left<Operand: Parsing, Operator: Parsing>
    where
        Operand.Input == Operator.Input,
        Operand.Input: Copyable & Restorable,
        Operand.Input.Checkpoint: Equatable
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

extension Parsers.Chain.Left: Parsing {
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

            guard input.checkpoint != saved.checkpoint else {
                input = saved
                break
            }

            result = combine(result, op, rhs)
        }

        return result
    }
}

extension Parsers.Chain {

    public struct Right<Operand: Parsing, Operator: Parsing>
    where
        Operand.Input == Operator.Input,
        Operand.Input: Copyable & Restorable,
        Operand.Input.Checkpoint: Equatable
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

extension Parsers.Chain.Right: Parsing {
    public typealias Input = Operand.Input
    public typealias Output = Operand.Output
    public typealias Failure = Operand.Failure

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        let entry = input.checkpoint

        let lhs = try operand.parse(&input)

        let saved = input

        let op: Operator.Output
        do throws(Operator.Failure) {
            op = try `operator`.parse(&input)
        } catch {

            input = saved
            return lhs
        }

        guard input.checkpoint != entry else {
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

extension Parsers.Chain {

    public struct Access<Operand: Parsing> {

        @usableFromInline
        let operand: Operand

        @usableFromInline
        init(operand: Operand) {
            self.operand = operand
        }

        @inlinable
        public func left<Op: Parsing>(
            _ op: Op,
            combine: @escaping (Operand.Output, Op.Output, Operand.Output) -> Operand.Output
        ) -> Parsers.Chain.Left<Operand, Op>
        where Op.Input == Operand.Input, Operand.Input: Copyable & Restorable, Operand.Input.Checkpoint: Equatable {
            Parsers.Chain.Left(operand: operand, operator: op, combine: combine)
        }

        @inlinable
        public func right<Op: Parsing>(
            _ op: Op,
            combine: @escaping (Operand.Output, Op.Output, Operand.Output) -> Operand.Output
        ) -> Parsers.Chain.Right<Operand, Op>
        where Op.Input == Operand.Input, Operand.Input: Copyable & Restorable, Operand.Input.Checkpoint: Equatable {
            Parsers.Chain.Right(operand: operand, operator: op, combine: combine)
        }
    }
}

extension Parsing {

    @inlinable
    public var chain: Parsers.Chain.Access<Self> {
        Parsers.Chain.Access(operand: self)
    }
}
