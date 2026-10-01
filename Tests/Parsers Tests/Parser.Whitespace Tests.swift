import Parsers_Test_Support
import Testing

@Suite
struct `Parsers.Whitespace` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

extension `Parsers.Whitespace`.Unit {
    @Test
    func `Horizontal consumes spaces`() throws {
        let parser = Parsers.Whitespace.Horizontal()
        var input = "   abc"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 3)
    }

    @Test
    func `Horizontal consumes tabs`() throws {
        let parser = Parsers.Whitespace.Horizontal()
        var input = "\t\tabc"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 2)
    }

    @Test
    func `Horizontal consumes mixed spaces and tabs`() throws {
        let parser = Parsers.Whitespace.Horizontal()
        var input = " \t abc"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 3)
    }

    @Test
    func `Skip is infallible and returns Void`() {
        let parser = Parsers.Whitespace.Skip()
        var input = "   abc"[...].utf8

        parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }
}

extension `Parsers.Whitespace`.`Edge Case` {
    @Test
    func `Horizontal fails with no whitespace`() {
        let parser = Parsers.Whitespace.Horizontal()
        var input = "abc"[...].utf8

        #expect(throws: Parsers.Constraint.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Skip succeeds with no whitespace`() {
        let parser = Parsers.Whitespace.Skip()
        var input = "abc"[...].utf8

        parser.parse(&input)

        #expect(input.first == UInt8(ascii: "a"))
    }

    @Test
    func `Skip on empty input`() {
        let parser = Parsers.Whitespace.Skip()
        var input = ""[...].utf8

        parser.parse(&input)

        #expect(input.isEmpty)
    }
}
