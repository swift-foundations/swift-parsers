import Parsers_Test_Support
import Testing

@Suite
struct `Parsers.Chain` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

private struct IntAtom: Parsing, Sendable {}

extension IntAtom {
    typealias Input = Substring.UTF8View
    typealias Output = Int
    typealias Failure = Parsers.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Int {
        var result = 0
        var hasDigit = false

        while let byte = input.first,
            byte >= UInt8(ascii: "0"),
            byte <= UInt8(ascii: "9")
        {
            result = result * 10 + Int(byte - UInt8(ascii: "0"))
            input.removeFirst()
            hasDigit = true
        }

        guard hasDigit else {
            throw .predicateFailed(description: "digit")
        }
        return result
    }
}

private struct PlusOp: Parsing, Sendable {}

extension PlusOp {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parsers.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: "+") else {
            throw .predicateFailed(description: "+")
        }
        input.removeFirst()
    }
}

private struct MinusOp: Parsing, Sendable {}

extension MinusOp {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parsers.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: "-") else {
            throw .predicateFailed(description: "-")
        }
        input.removeFirst()
    }
}

private struct CaretOp: Parsing, Sendable {}

extension CaretOp {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parsers.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: "^") else {
            throw .predicateFailed(description: "^")
        }
        input.removeFirst()
    }
}

private struct DoublePlusOp: Parsing, Sendable {}

extension DoublePlusOp {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parsers.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: "+") else {
            throw .predicateFailed(description: "++")
        }
        input.removeFirst()
        guard input.first == UInt8(ascii: "+") else {
            throw .predicateFailed(description: "++")
        }
        input.removeFirst()
    }
}

extension `Parsers.Chain`.Unit {
    @Test
    func `Left - left-associative addition`() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }
        var input = "1+2+3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 6)
    }

    @Test
    func `Left - left-associative subtraction`() throws {
        let parser = IntAtom().chain.left(MinusOp()) { lhs, _, rhs in
            lhs - rhs
        }
        var input = "10-3-2"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 5)
    }

    @Test
    func `Right - right-associative`() throws {
        let parser = IntAtom().chain.right(CaretOp()) { lhs, _, rhs in
            lhs * 10 + rhs
        }
        var input = "1^2^3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 33)
    }
}

extension `Parsers.Chain`.`Edge Case` {
    @Test
    func `Left - single operand`() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }
        var input = "42"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 42)
    }

    @Test
    func `Right - single operand`() throws {
        let parser = IntAtom().chain.right(CaretOp()) { lhs, _, rhs in
            lhs + rhs
        }
        var input = "99"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 99)
    }

    @Test
    func `Left - operator fails after first operand`() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }
        var input = "7*3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 7)
        #expect(input.first == UInt8(ascii: "*"))
    }

    @Test
    func `Left - operator partially consumes before failing, input is restored`() throws {
        let parser = IntAtom().chain.left(DoublePlusOp()) { lhs, _, rhs in
            lhs + rhs
        }
        var input = "5+3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 5)
        #expect(String(decoding: input, as: UTF8.self) == "+3")
    }

    @Test
    func `Right - operator partially consumes before failing, input is restored`() throws {
        let parser = IntAtom().chain.right(DoublePlusOp()) { lhs, _, rhs in
            lhs + rhs
        }
        var input = "5+3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 5)
        #expect(String(decoding: input, as: UTF8.self) == "+3")
    }
}
