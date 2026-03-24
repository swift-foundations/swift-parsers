import Testing
import Parsers_Test_Support

@Suite("Parser.Between")
struct ParserBetweenTests {
    @Suite struct Unit {}
    @Suite struct EdgeCase {}
}

// MARK: - Helpers

private struct CharParser: Parser.`Protocol`, Sendable {
    let byte: UInt8

    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == byte else {
            throw .predicateFailed(description: "\(byte)")
        }
        input.removeFirst()
    }
}

private struct ContentParser: Parser.`Protocol`, Sendable {
    typealias Input = Substring.UTF8View
    typealias Output = Int
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Int {
        var count = 0
        while let byte = input.first, byte != UInt8(ascii: ")"), byte != UInt8(ascii: "]") {
            input.removeFirst()
            count += 1
        }
        guard count > 0 else {
            throw .predicateFailed(description: "content")
        }
        return count
    }
}

// MARK: - Unit Tests

extension ParserBetweenTests.Unit {
    @Test
    func `matched parentheses`() throws {
        let open = CharParser(byte: UInt8(ascii: "("))
        let close = CharParser(byte: UInt8(ascii: ")"))
        let content = ContentParser()
        let parser = content.between(open, close)
        var input = "(abc)"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 3)
        #expect(input.isEmpty)
    }

    @Test
    func `matched brackets`() throws {
        let open = CharParser(byte: UInt8(ascii: "["))
        let close = CharParser(byte: UInt8(ascii: "]"))
        let content = ContentParser()
        let parser = content.between(open, close)
        var input = "[xyz]rest"[...].utf8

        let result = try parser.parse(&input)

        #expect(result == 3)
        #expect(input.first == UInt8(ascii: "r"))
    }
}

// MARK: - Edge Case Tests

extension ParserBetweenTests.EdgeCase {
    @Test
    func `missing open delimiter fails`() {
        let open = CharParser(byte: UInt8(ascii: "("))
        let close = CharParser(byte: UInt8(ascii: ")"))
        let content = ContentParser()
        let parser = content.between(open, close)
        var input = "abc)"[...].utf8

        #expect(throws: (any Swift.Error).self) {
            try parser.parse(&input)
        }
    }

    @Test
    func `missing close delimiter fails`() {
        let open = CharParser(byte: UInt8(ascii: "("))
        let close = CharParser(byte: UInt8(ascii: ")"))
        let content = ContentParser()
        let parser = content.between(open, close)
        var input = "(abc"[...].utf8

        #expect(throws: (any Swift.Error).self) {
            try parser.parse(&input)
        }
    }
}
