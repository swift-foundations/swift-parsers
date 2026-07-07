import Parsers_Test_Support
import Testing

@Suite
struct `Parser.Whitespace` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

// MARK: - Unit Tests

extension `Parser.Whitespace`.Unit {
    @Test
    func `Horizontal consumes spaces`() throws {
        let parser = Parser.Whitespace.Horizontal()
        var input = "   abc"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 3)
    }

    @Test
    func `Horizontal consumes tabs`() throws {
        let parser = Parser.Whitespace.Horizontal()
        var input = "\t\tabc"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 2)
    }

    @Test
    func `Horizontal consumes mixed spaces and tabs`() throws {
        let parser = Parser.Whitespace.Horizontal()
        var input = " \t abc"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 3)
    }

    @Test
    func `Skip is infallible and returns Void`() {
        let parser = Parser.Whitespace.Skip()
        var input = "   abc"[...].utf8

        parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }
}

// MARK: - Edge Case Tests

extension `Parser.Whitespace`.`Edge Case` {
    @Test
    func `Horizontal fails with no whitespace`() {
        let parser = Parser.Whitespace.Horizontal()
        var input = "abc"[...].utf8

        #expect(throws: Parser.Constraint.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Skip succeeds with no whitespace`() {
        let parser = Parser.Whitespace.Skip()
        var input = "abc"[...].utf8

        parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `Skip on empty input`() {
        let parser = Parser.Whitespace.Skip()
        var input = ""[...].utf8

        parser.parse(&input)

        #expect(input.isEmpty)
    }
}
