import Parsers_Test_Support
import Testing

@Suite
struct `Parser.Comment` {
    @Suite struct Unit {}
    @Suite struct `Edge Case` {}
}

// MARK: - Unit Tests

extension `Parser.Comment`.Unit {
    @Test
    func `Line parses C-style comment`() throws {
        let parser = Parser.Comment.Line()
        var input = "// hello\nworld"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == " hello")
        #expect(input.first == UInt8(ascii: "\n"))
    }

    @Test
    func `Line parses hash comment`() throws {
        let parser = Parser.Comment.Line(prefix: "#")
        var input = "# comment\nnext"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == " comment")
    }

    @Test
    func `Block parses simple block comment`() throws {
        let parser = Parser.Comment.Block()
        var input = "/* hello */rest"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == " hello ")
        #expect(input.first == UInt8(ascii: "r"))
    }

    @Test
    func `Block parses nested comment when nestable`() throws {
        let parser = Parser.Comment.Block(nestable: true)
        var input = "/* outer /* inner */ end */rest"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == " outer /* inner */ end ")
        #expect(input.first == UInt8(ascii: "r"))
    }
}

// MARK: - Edge Case Tests

extension `Parser.Comment`.`Edge Case` {
    @Test
    func `Line fails without prefix`() {
        let parser = Parser.Comment.Line()
        var input = "not a comment"[...].utf8

        #expect(throws: Parser.Match.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Block fails when unterminated`() {
        let parser = Parser.Comment.Block()
        var input = "/* unclosed"[...].utf8

        #expect(throws: Parser.Comment.Block.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Block fails without opening delimiter`() {
        let parser = Parser.Comment.Block()
        var input = "not a comment */"[...].utf8

        #expect(throws: Parser.Comment.Block.Error.self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `Line parses to end when no newline`() throws {
        let parser = Parser.Comment.Line()
        var input = "// final comment"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == " final comment")
        #expect(input.isEmpty)
    }
}
