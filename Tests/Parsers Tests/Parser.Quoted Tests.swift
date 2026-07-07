import Parsers_Test_Support
import Testing

@Suite
struct `Parser.Quoted` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

// MARK: - Unit Tests

extension `Parser.Quoted`.Unit {
    @Test
    func `Double parses simple string`() throws {
        let parser = Parser.Quoted.Double()
        var input = "\"hello\"rest"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == "hello")
        #expect(input.first == UInt8(ascii: "r"))
    }

    @Test
    func `Double parses escape sequences`() throws {
        let parser = Parser.Quoted.Double()
        var input = "\"a\\nb\""[...].utf8

        let result = try parser.parse(&input)

        #expect(result == "a\nb")
    }

    @Test
    func `Single parses literal content`() throws {
        let parser = Parser.Quoted.Single()
        var input = "'hello'rest"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == "hello")
        #expect(input.first == UInt8(ascii: "r"))
    }

    @Test
    func `Doubling parses escaped quote`() throws {
        let parser = Parser.Quoted.Doubling()
        var input = "\"say \"\"hi\"\"\"rest"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == "say \"hi\"")
    }
}

// MARK: - Edge Case Tests

extension `Parser.Quoted`.`Edge Case` {
    @Test
    func `Double fails on unclosed string`() {
        let parser = Parser.Quoted.Double()
        var input = "\"unclosed"[...].utf8

        #expect(throws: Parser.Quoted.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Double fails on missing open quote`() {
        let parser = Parser.Quoted.Double()
        var input = "no quotes"[...].utf8

        #expect(throws: Parser.Quoted.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Double parses empty string`() throws {
        let parser = Parser.Quoted.Double()
        var input = "\"\""[...].utf8

        let result = try parser.parse(&input)

        #expect(result.isEmpty)
    }
}
