//
//  IntegerTests.swift
//  swift-parsing
//
//  Tests for integer parsers.
//

import Testing
import Parsing

@Suite("Integer Parsers")
struct IntegerTests {

    @Test("Decimal - basic parsing")
    func decimalBasic() throws {
        let parser = Parsing.Integer<Int>.Decimal()
        var input = "123"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 123)
        #expect(input.isEmpty)
    }

    @Test("Decimal - negative")
    func decimalNegative() throws {
        let parser = Parsing.Integer<Int>.Decimal()
        var input = "-456"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == -456)
    }

    @Test("Decimal - positive sign")
    func decimalPositive() throws {
        let parser = Parsing.Integer<Int>.Decimal()
        var input = "+789"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 789)
    }

    @Test("Decimal - no sign when disabled")
    func decimalNoSign() throws {
        let parser = Parsing.Integer<UInt>.Decimal(allowSign: false)
        var input = "123"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 123)
    }

    @Test("Hexadecimal - basic")
    func hexBasic() throws {
        let parser = Parsing.Integer<UInt32>.Hexadecimal()
        var input = "FF"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 255)
    }

    @Test("Hexadecimal - with prefix")
    func hexWithPrefix() throws {
        let parser = Parsing.Integer<UInt32>.Hexadecimal()
        var input = "0xFF"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 255)
    }

    @Test("Hexadecimal - required prefix")
    func hexRequiredPrefix() throws {
        let parser = Parsing.Integer<UInt32>.Hexadecimal(requirePrefix: true)
        var input = "0xABCD"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 0xABCD)
    }

    @Test("Binary - basic")
    func binaryBasic() throws {
        let parser = Parsing.Integer<UInt8>.Binary()
        var input = "1010"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 10)
    }

    @Test("Binary - with prefix")
    func binaryWithPrefix() throws {
        let parser = Parsing.Integer<UInt8>.Binary()
        var input = "0b1111"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 15)
    }

    @Test("Octal - basic")
    func octalBasic() throws {
        let parser = Parsing.Integer<Int>.Octal()
        var input = "777"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 511)  // 7*64 + 7*8 + 7 = 511
    }
}
