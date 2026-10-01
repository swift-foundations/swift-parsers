import Parsers_Test_Support
import Testing

@Suite
struct `Parsers.Newline` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

extension `Parsers.Newline`.Unit {
    @Test
    func `LF matches line feed`() throws {
        let parser = Parsers.Newline.LF()
        var input = "\nabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `CR matches carriage return`() throws {
        let parser = Parsers.Newline.CR()
        var input = "\rabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `CRLF matches carriage return line feed`() throws {
        let parser = Parsers.Newline.CRLF()
        var input = "\r\nabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `Any matches LF`() throws {
        let parser = Parsers.Newline.Any()
        var input = "\nabc"[...].utf8

        try parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }
}

extension `Parsers.Newline`.`Edge Case` {
    @Test
    func `LF fails on non-newline`() {
        let parser = Parsers.Newline.LF()
        var input = "abc"[...].utf8

        #expect(throws: Parsers.Match.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Line consumes until newline`() {
        let parser = Parsers.Newline.Line()
        var input = "hello\nworld"[...].utf8

        let count = parser.parse(&input)

        #expect(count == 5)
        #expect(input.first == UInt8(ascii: "\n"))
    }

    @Test
    func `Line on empty input returns zero`() {
        let parser = Parsers.Newline.Line()
        var input = ""[...].utf8

        let count = parser.parse(&input)

        #expect(count == 0)
    }

    @Test
    func `Line consumes to end when no newline`() {
        let parser = Parsers.Newline.Line()
        var input = "hello"[...].utf8

        let count = parser.parse(&input)

        #expect(count == 5)
        #expect(input.isEmpty)
    }
}
