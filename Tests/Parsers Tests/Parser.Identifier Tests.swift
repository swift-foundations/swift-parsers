import Parsers_Test_Support
import Testing

@Suite
struct `Parser.Identifier` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

// MARK: - Unit Tests

extension `Parser.Identifier`.Unit {
    @Test
    func `CStyle matches simple identifier`() throws {
        let parser = Parser.Identifier.CStyle()
        var input = "hello world"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 5)
    }

    @Test
    func `CStyle matches identifier with underscore`() throws {
        let parser = Parser.Identifier.CStyle()
        var input = "my_var = 1"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 6)
    }

    @Test
    func `CStyle matches underscore-only identifier`() throws {
        let parser = Parser.Identifier.CStyle()
        var input = "_"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 1)
    }

    @Test
    func `CStyle matches identifier with digits`() throws {
        let parser = Parser.Identifier.CStyle()
        var input = "x123"[...].utf8

        let count = try parser.parse(&input)

        #expect(count == 4)
    }
}

// MARK: - Edge Case Tests

extension `Parser.Identifier`.`Edge Case` {
    @Test
    func `CStyle fails when starting with digit`() {
        let parser = Parser.Identifier.CStyle()
        var input = "123abc"[...].utf8

        #expect(throws: Parser.Match.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `CStyle fails on empty input`() {
        let parser = Parser.Identifier.CStyle()
        var input = ""[...].utf8

        #expect(throws: Parser.Match.Error.self) {
            try parser.parse(&input)
        }
    }
}
