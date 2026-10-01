import Parsers_Test_Support
import Testing

@Suite
struct `Parsers.Expression` {
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

private struct OpParser: Parsing, Sendable {
    let byte: UInt8
}

extension OpParser {
    typealias Input = Substring.UTF8View
    typealias Output = UInt8
    typealias Failure = Parsers.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> UInt8 {
        guard input.first == byte else {
            throw .predicateFailed(description: "\(byte)")
        }
        input.removeFirst()
        return byte
    }
}

private func makeArithmeticParser() -> Parsers.Expression.Climbing<IntAtom, OpParser> {
    Parsers.Expression.Climbing(
        atom: IntAtom(),
        operators: [
            .init(parser: OpParser(byte: UInt8(ascii: "+")), precedence: 1, associativity: .left) {
                $0 + $1
            },
            .init(parser: OpParser(byte: UInt8(ascii: "-")), precedence: 1, associativity: .left) {
                $0 - $1
            },
            .init(parser: OpParser(byte: UInt8(ascii: "*")), precedence: 2, associativity: .left) {
                $0 * $1
            },
        ]
    )
}

extension `Parsers.Expression`.Unit {
    @Test
    func `precedence - multiply before add`() throws {
        let parser = makeArithmeticParser()
        var input = "2+3*4"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 14)
    }

    @Test
    func `precedence - subtract and multiply`() throws {
        let parser = makeArithmeticParser()
        var input = "10-2*3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 4)
    }

    @Test
    func `left associativity for same precedence`() throws {
        let parser = makeArithmeticParser()
        var input = "10-3-2"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 5)
    }

    @Test
    func `complex expression`() throws {
        let parser = makeArithmeticParser()
        var input = "1+2*3+4"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 11)
    }
}

extension `Parsers.Expression`.`Edge Case` {
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

        #expect(throws: Parsers.Match.Error.self) {
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
        let parser = Parsers.Expression.Climbing(
            atom: IntAtom(),
            operators: [
                .init(
                    parser: OpParser(byte: UInt8(ascii: "+")),
                    precedence: 1,
                    associativity: .left
                ) { $0 + $1 }
            ],
            prefix: [
                .init(parser: negParser) { -$0 }
            ]
        )
        var input = "-3+5"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 2)
    }
}
