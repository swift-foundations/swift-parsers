//
//  ArithmeticTests.swift
//  swift-parsing
//
//  Integration tests for arithmetic expression parsing.
//

import Parsers_Test_Support
import Testing

@Suite
struct `Arithmetic Expression Parsing` {

    // Simple integer parser for atoms
    struct IntAtom: Parser.`Protocol`, Sendable {}

    // Simple operator parser
    struct PlusOp: Parser.`Protocol`, Sendable {}

    struct MinusOp: Parser.`Protocol`, Sendable {}

    struct StarOp: Parser.`Protocol`, Sendable {}

    @Test
    func `ChainLeft - simple addition`() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }

        var input = "1+2+3"[...].utf8
        let result = try parser.parse(&input)
        #expect(result == 6)  // (1+2)+3 = 6
    }

    @Test
    func `ChainLeft - single operand`() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }

        var input = "42"[...].utf8
        let result = try parser.parse(&input)
        #expect(result == 42)
    }
}

extension `Arithmetic Expression Parsing`.IntAtom {
    typealias Input = Substring.UTF8View
    typealias Output = Int
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) -> Int {
        var result = 0
        var hasDigit = false

        while let byte = input.first,
            byte >= UInt8(ascii: "0"),
            byte <= UInt8(ascii: "9")
        {
            result = result * 10 + Int(byte - UInt8(ascii: "0"))
            input.removeFirst()
            hasDigit = true
        }

        guard hasDigit else {
            throw .predicateFailed(description: "digit")
        }

        return result
    }
}

extension `Arithmetic Expression Parsing`.PlusOp {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: "+") else {
            throw .predicateFailed(description: "+")
        }
        input.removeFirst()
    }
}

extension `Arithmetic Expression Parsing`.MinusOp {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: "-") else {
            throw .predicateFailed(description: "-")
        }
        input.removeFirst()
    }
}

extension `Arithmetic Expression Parsing`.StarOp {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parser.Match.Error

    func parse(_ input: inout Input) throws(Failure) {
        guard input.first == UInt8(ascii: "*") else {
            throw .predicateFailed(description: "*")
        }
        input.removeFirst()
    }
}
