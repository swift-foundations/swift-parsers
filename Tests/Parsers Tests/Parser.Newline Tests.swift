import Testing
import Parsers_Test_Support

@Suite("Parser.Newline")
struct ParserNewlineTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Unit Tests

extension ParserNewlineTests.Unit {
    @Test
    func `LF matches line feed`() throws {
        let parser = Parser.Newline.LF()
        var input = "\nabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `CR matches carriage return`() throws {
        let parser = Parser.Newline.CR()
        var input = "\rabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `CRLF matches carriage return line feed`() throws {
        let parser = Parser.Newline.CRLF()
        var input = "\r\nabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `Any matches LF`() throws {
        let parser = Parser.Newline.Any()
        var input = "\nabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }
}

// MARK: - Edge Case Tests

extension ParserNewlineTests.EdgeCase {
    @Test
    func `LF fails on non-newline`() {
        let parser = Parser.Newline.LF()
        var input = "abc"[...].utf8

        #expect(throws: Parser.Match.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Line consumes until newline`() {
        let parser = Parser.Newline.Line()
        var input = "hello\nworld"[...].utf8

        let count = parser.parse(&input)

        #expect(count == 5)
        #expect(input.first == UInt8(ascii: "\n"))
    }

    @Test
    func `Line on empty input returns zero`() {
        let parser = Parser.Newline.Line()
        var input = ""[...].utf8

        let count = parser.parse(&input)

        #expect(count == 0)
    }

    @Test
    func `Line consumes to end when no newline`() {
        let parser = Parser.Newline.Line()
        var input = "hello"[...].utf8

        let count = parser.parse(&input)

        #expect(count == 5)
        #expect(input.isEmpty)
    }
}
