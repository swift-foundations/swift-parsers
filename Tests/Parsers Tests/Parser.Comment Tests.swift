import Parsers_Test_Support
import Testing

@Suite("Parser.Comment")
struct ParserCommentTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Unit Tests

extension ParserCommentTests.Unit {
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

extension ParserCommentTests.EdgeCase {
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
