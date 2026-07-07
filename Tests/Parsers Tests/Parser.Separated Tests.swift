import Parsers_Test_Support
import Testing

@Suite
struct `Parser.Separated` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

// MARK: - Helpers

private struct DigitParser: Parser.`Protocol`, Sendable {}

extension DigitParser {
    typealias Input = Substring.UTF8View
    typealias Output = Int
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Int {
        guard let byte = input.first,
            byte >= UInt8(ascii: "0"),
            byte <= UInt8(ascii: "9")
        else {
            throw .predicateFailed(description: "digit")
        }
        input.removeFirst()
        return Int(byte - UInt8(ascii: "0"))
    }
}

private struct CommaParser: Parser.`Protocol`, Sendable {}

extension CommaParser {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: ",") else {
            throw .predicateFailed(description: ",")
        }
        input.removeFirst()
    }
}

// MARK: - Unit Tests

extension `Parser.Separated`.Unit {
    @Test
    func `basic CSV-like separation`() throws {
        let parser = DigitParser().separated(by: CommaParser())
        var input = "1,2,3"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == [1, 2, 3])
        #expect(input.isEmpty)
    }

    @Test
    func `single element`() throws {
        let parser = DigitParser().separated(by: CommaParser())
        var input = "5"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == [5])
    }

    @Test
    func `trailing separator allowed`() throws {
        let parser = DigitParser().separated(by: CommaParser(), allowTrailing: true)
        var input = "1,2,"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == [1, 2])
        #expect(input.isEmpty)
    }

    @Test
    func `trailing separator not consumed when disallowed`() throws {
        let parser = DigitParser().separated(by: CommaParser())
        var input = "1,2,"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == [1, 2])
        #expect(input.first == UInt8(ascii: ","))
    }
}

// MARK: - Edge Case Tests

extension `Parser.Separated`.`Edge Case` {
    @Test
    func `empty input returns empty array`() throws {
        let parser = DigitParser().separated(by: CommaParser())
        var input = ""[...].utf8

        let result = try parser.parse(&input)

        #expect(result.isEmpty)
    }

    @Test
    func `minCount enforced`() {
        let parser = Parser.Separated(
            element: DigitParser(),
            separator: CommaParser(),
            minCount: 3
        )
        var input = "1,2"[...].utf8

        #expect(throws: (any Swift.Error).self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `maxCount caps elements`() throws {
        let parser = Parser.Separated(
            element: DigitParser(),
            separator: CommaParser(),
            maxCount: 2
        )
        var input = "1,2,3,4"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == [1, 2])
        #expect(input.first == UInt8(ascii: ","))
    }

    @Test
    func `no match when element fails`() throws {
        let parser = DigitParser().separated(by: CommaParser())
        var input = "abc"[...].utf8

        let result = try parser.parse(&input)

        #expect(result.isEmpty)
    }
}
