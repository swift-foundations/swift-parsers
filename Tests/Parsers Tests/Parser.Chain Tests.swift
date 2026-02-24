import Testing
import Parsers_Test_Support

@Suite("Parser.Chain")
struct ParserChainTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Helpers

private struct IntAtom: Parser.`Protocol`, Sendable {
    typealias Input = Substring.UTF8View
    typealias ParseOutput = Int
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Int {
        var result = 0
        var hasDigit = false

        while let byte = input.first,
              byte >= UInt8(ascii: "0"),
              byte <= UInt8(ascii: "9") {
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

private struct PlusOp: Parser.`Protocol`, Sendable {
    typealias Input = Substring.UTF8View
    typealias ParseOutput = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == UInt8(ascii: "+") else {
            throw .predicateFailed(description: "+")
        }
        input.removeFirst()
    }
}

private struct MinusOp: Parser.`Protocol`, Sendable {
    typealias Input = Substring.UTF8View
    typealias ParseOutput = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == UInt8(ascii: "-") else {
            throw .predicateFailed(description: "-")
        }
        input.removeFirst()
    }
}

private struct CaretOp: Parser.`Protocol`, Sendable {
    typealias Input = Substring.UTF8View
    typealias ParseOutput = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == UInt8(ascii: "^") else {
            throw .predicateFailed(description: "^")
        }
        input.removeFirst()
    }
}

// MARK: - Unit Tests

extension ParserChainTests.Unit {
    @Test
    func `Left - left-associative addition`() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }
        var input = "1+2+3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 6) // (1+2)+3
    }

    @Test
    func `Left - left-associative subtraction`() throws {
        let parser = IntAtom().chain.left(MinusOp()) { lhs, _, rhs in
            lhs - rhs
        }
        var input = "10-3-2"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 5) // (10-3)-2
    }

    @Test
    func `Right - right-associative`() throws {
        let parser = IntAtom().chain.right(CaretOp()) { lhs, _, rhs in
            lhs * 10 + rhs
        }
        var input = "1^2^3"[...].utf8

        let result = try parser.parse(&input)

        // Right-associative: 1^(2^3) = 1*10+(2*10+3) = 1*10+23 = 33
        #expect(result == 33)
    }
}

// MARK: - Edge Case Tests

extension ParserChainTests.EdgeCase {
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
}
