import Parsers_Test_Support
import Testing

@Suite
struct `Parser.Diagnostic.Source` {
    @Suite struct `Line Starts` {}
    @Suite struct `Line Content` {}
}

// MARK: - Line Start Computation

extension `Parser.Diagnostic.Source`.`Line Starts` {
    @Test
    func `Single line has one line start`() {
        let source = Parser.Diagnostic.Source(content: "hello")
        #expect(source.line(1) == "hello")
        #expect(source.line(2) == nil)
    }

    @Test
    func `Two lines separated by newline`() {
        let source = Parser.Diagnostic.Source(content: "line1\nline2")
        #expect(source.line(1) == "line1")
        #expect(source.line(2) == "line2")
        #expect(source.line(3) == nil)
    }

    @Test
    func `Multiple lines`() {
        let source = Parser.Diagnostic.Source(content: "aaa\nbbb\nccc\nddd")
        #expect(source.line(1) == "aaa")
        #expect(source.line(2) == "bbb")
        #expect(source.line(3) == "ccc")
        #expect(source.line(4) == "ddd")
        #expect(source.line(5) == nil)
    }

    @Test
    func `Trailing newline does not create phantom line`() {
        let source = Parser.Diagnostic.Source(content: "aaa\nbbb\n")
        #expect(source.line(1) == "aaa")
        // Last line includes trailing newline (no next lineStart to trim against)
        #expect(source.line(2) == "bbb\n")
        #expect(source.line(3) == nil)
    }

    @Test
    func `Empty content has one line`() {
        let source = Parser.Diagnostic.Source(content: "")
        #expect(source.line(1)?.isEmpty == true)
        #expect(source.line(2) == nil)
    }

    @Test
    func `Consecutive newlines create empty lines`() {
        let source = Parser.Diagnostic.Source(content: "a\n\nb")
        #expect(source.line(1) == "a")
        #expect(source.line(2)?.isEmpty == true)
        #expect(source.line(3) == "b")
    }
}

// MARK: - Line Content with Unicode

extension `Parser.Diagnostic.Source`.`Line Content` {
    @Test
    func `Multi-byte UTF-8 on a line`() {
        let source = Parser.Diagnostic.Source(content: "café\nnaïve")
        #expect(source.line(1) == "café")
        #expect(source.line(2) == "naïve")
    }

    @Test
    func `Emoji on a line`() {
        let source = Parser.Diagnostic.Source(content: "hello 🌍\nworld 🚀")
        #expect(source.line(1) == "hello 🌍")
        #expect(source.line(2) == "world 🚀")
    }

    @Test
    func `Line number out of range returns nil`() {
        let source = Parser.Diagnostic.Source(content: "a\nb")
        #expect(source.line(0) == nil)
        #expect(source.line(-1) == nil)
        #expect(source.line(3) == nil)
    }

    @Test
    func `Large content with many lines`() {
        // Exercises the O(n) scan — previously O(n²)
        let lines = (0..<1000).map { "line \($0)" }
        let content = lines.joined(separator: "\n")
        let source = Parser.Diagnostic.Source(content: content)

        #expect(source.line(1) == "line 0")
        #expect(source.line(500) == "line 499")
        #expect(source.line(1000) == "line 999")
        #expect(source.line(1001) == nil)
    }
}
