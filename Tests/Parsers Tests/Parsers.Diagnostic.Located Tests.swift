import Ordinal
import Parsers_Test_Support
import Testing
import Text

private func position(_ offset: UInt) -> Text.Position {
    Text.Position(_unchecked: Ordinal(offset))
}

@Suite
struct `Parsers.Diagnostic.Located Tests` {

    @Test
    func `the wrapper exposes its error and offset`() {
        let located = Parsers.Diagnostic.Located(Parsers.Match.Error.expectedEnd(remaining: 3), at: position(4))
        #expect(located.error == .expectedEnd(remaining: 3))
        #expect(Int(bitPattern: located.offset) == 4)
        #expect(located.description == "at offset \(located.offset): \(located.error)")
    }

    @Test
    func `map transforms the error and keeps the offset`() {
        let located = Parsers.Diagnostic.Located(Parsers.Match.Error.predicateFailed(description: "digit"), at: position(7))
        let mapped = located.map { _ in Parsers.Constraint.Error.countTooLow(expected: 1, got: 0) }
        #expect(mapped.error == .countTooLow(expected: 1, got: 0))
        #expect(mapped.offset == located.offset)
    }

    @Test(arguments: [
        Parsers.Diagnostic.Style.compact,
        Parsers.Diagnostic.Style.expanded(),
        Parsers.Diagnostic.Style.caret,
        Parsers.Diagnostic.Style.rich,
    ])
    func `formatted formats the wrapper at its offset`(_ style: Parsers.Diagnostic.Style) {
        let source = Parsers.Diagnostic.Source(content: "let x = 1\nlet y = ?\n")
        let located = Parsers.Diagnostic.Located(Parsers.Match.Error.literalMismatch(expected: "1", found: "?"), at: position(18))
        #expect(located.formatted(in: source, style: style) == Parsers.Diagnostic.format(located, at: located.offset, in: source, style: style))
    }

    @Test
    func `formatted defaults to the expanded style`() {
        let source = Parsers.Diagnostic.Source(content: "abc\ndef\n")
        let located = Parsers.Diagnostic.Located(Parsers.Match.Error.byteMismatch(expected: [0x61], found: [0x64]), at: position(4))
        #expect(located.formatted(in: source) == Parsers.Diagnostic.format(located, at: located.offset, in: source, style: .expanded()))
    }

    @Test
    func `offsets are UTF-8 bytes, so a multibyte character before the error shifts the column`() {
        let source = Parsers.Diagnostic.Source(content: "é = ?")
        let location = source.location(at: position(5))
        #expect(location.line == 1)
        #expect(location.column == 6)
    }

    @Test
    func `the local failure types keep their historical cases`() {
        #expect(Parsers.Match.Error.literalMismatch(expected: "a", found: "b") != .literalMismatch(expected: "a", found: "c"))
        #expect(Parsers.Match.Error.expectedEnd(remaining: 1) == .expectedEnd(remaining: 1))
        #expect(Parsers.Constraint.Error.countTooHigh(expected: 2, got: 3) == .countTooHigh(expected: 2, got: 3))
        #expect(Parsers.Constraint.Error.validationFailed(value: "x", reason: "y") != .countTooLow(expected: 1, got: 0))
    }
}
