import Testing
import Parsers_Test_Support

@Suite("Parser.Expression")
struct ParserExpressionTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Helpers

private struct IntAtom: Parser.`Protocol`, Sendable {
    typealias Input = Substring.UTF8View
    typealias Output = Int
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

private struct OpParser: Parser.`Protocol`, Sendable {
    let byte: UInt8

    typealias Input = Substring.UTF8View
    typealias Output = UInt8
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> UInt8 {
        guard input.first == byte else {
            throw .predicateFailed(description: "\(byte)")
        }
        input.removeFirst()
        return byte
    }
}

private func makeArithmeticParser() -> Parser.Expression.Climbing<IntAtom, OpParser> {
    Parser.Expression.Climbing(
        atom: IntAtom(),
        operators: [
            .init(parser: OpParser(byte: UInt8(ascii: "+")), precedence: 1, associativity: .left) { $0 + $1 },
            .init(parser: OpParser(byte: UInt8(ascii: "-")), precedence: 1, associativity: .left) { $0 - $1 },
            .init(parser: OpParser(byte: UInt8(ascii: "*")), precedence: 2, associativity: .left) { $0 * $1 },
        ]
    )
}

// MARK: - Unit Tests

extension ParserExpressionTests.Unit {
    @Test
    func `precedence - multiply before add`() throws {
        let parser = makeArithmeticParser()
        var input = "2+3*4"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 14) // 2+(3*4)
    }

    @Test
    func `precedence - subtract and multiply`() throws {
        let parser = makeArithmeticParser()
        var input = "10-2*3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 4) // 10-(2*3)
    }

    @Test
    func `left associativity for same precedence`() throws {
        let parser = makeArithmeticParser()
        var input = "10-3-2"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 5) // (10-3)-2
    }

    @Test
    func `complex expression`() throws {
        let parser = makeArithmeticParser()
        var input = "1+2*3+4"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 11) // 1+(2*3)+4
    }
}

// MARK: - Edge Case Tests

extension ParserExpressionTests.EdgeCase {
    @Test
    func `single atom`() throws {
        let parser = makeArithmeticParser()
        var input = "42"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 42)
    }

    @Test
    func `atom fails`() {
        let parser = makeArithmeticParser()
        var input = "+3"[...].utf8

        #expect(throws: Parser.Match.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `unknown operator stops parsing`() throws {
        let parser = makeArithmeticParser()
        var input = "5^2"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 5)
        #expect(input.first == UInt8(ascii: "^"))
    }

    @Test
    func `prefix operator - unary minus`() throws {
        let negParser = OpParser(byte: UInt8(ascii: "-"))
        let parser = Parser.Expression.Climbing(
            atom: IntAtom(),
            operators: [
                .init(parser: OpParser(byte: UInt8(ascii: "+")), precedence: 1, associativity: .left) { $0 + $1 },
            ],
            prefix: [
                .init(parser: negParser) { -$0 },
            ]
        )
        var input = "-3+5"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 2)
    }
}
