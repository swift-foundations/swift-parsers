//
//  IntegerTests.swift
//  swift-parsing
//
//  Tests for integer parsers.
//

import Testing
import Parsers_Test_Support

@Suite("Integer Parsers")
struct IntegerTests {

    @Test
    func `Decimal - basic parsing`() throws {
        let parser = Parser.Integer<Int>.Decimal()
        var input = "123"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 123)
        #expect(input.isEmpty)
    }

    @Test
    func `Decimal - negative`() throws {
        let parser = Parser.Integer<Int>.Decimal()
        var input = "-456"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == -456)
    }

    @Test
    func `Decimal - positive sign`() throws {
        let parser = Parser.Integer<Int>.Decimal()
        var input = "+789"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 789)
    }

    @Test
    func `Decimal - no sign when disabled`() throws {
        let parser = Parser.Integer<UInt>.Decimal(allowSign: false)
        var input = "123"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 123)
    }

    @Test
    func `Hexadecimal - basic`() throws {
        let parser = Parser.Integer<UInt32>.Hexadecimal()
        var input = "FF"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 255)
    }

    @Test
    func `Hexadecimal - with prefix`() throws {
        let parser = Parser.Integer<UInt32>.Hexadecimal()
        var input = "0xFF"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 255)
    }

    @Test
    func `Hexadecimal - required prefix`() throws {
        let parser = Parser.Integer<UInt32>.Hexadecimal(requirePrefix: true)
        var input = "0xABCD"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 0xABCD)
    }

    @Test
    func `Binary - basic`() throws {
        let parser = Parser.Integer<UInt8>.Binary()
        var input = "1010"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 10)
    }

    @Test
    func `Binary - with prefix`() throws {
        let parser = Parser.Integer<UInt8>.Binary()
        var input = "0b1111"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 15)
    }

    @Test
    func `Octal - basic`() throws {
        let parser = Parser.Integer<Int>.Octal()
        var input = "777"[...].utf8
        let value = try parser.parse(&input)
        #expect(value == 511)  // 7*64 + 7*8 + 7 = 511
    }
}
