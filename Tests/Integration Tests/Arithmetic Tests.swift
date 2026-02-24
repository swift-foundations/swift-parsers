//
//  ArithmeticTests.swift
//  swift-parsing
//
//  Integration tests for arithmetic expression parsing.
//

import Testing
import Parsers_Test_Support

@Suite("Arithmetic Expression Parsing")
struct ArithmeticTests {

    // Simple integer parser for atoms
    struct IntAtom: Parser.`Protocol`, Sendable {
        typealias Input = Substring.UTF8View
        typealias Output = Int
        typealias Failure = Parser.Match.Error

        func parse(_ input: inout Input) throws(Failure) -> Int {
            var result = 0
            var hasDigit = false

            while let byte = input.first,
                  byte >= UInt8(ascii: "0"),
                  byte <= UInt8(ascii: "9") {
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

    // Simple operator parser
    struct PlusOp: Parser.`Protocol`, Sendable {
        typealias Input = Substring.UTF8View
        typealias Output = Void
        typealias Failure = Parser.Match.Error

        func parse(_ input: inout Input) throws(Failure) -> Void {
            guard input.first == UInt8(ascii: "+") else {
                throw .predicateFailed(description: "+")
            }
            input.removeFirst()
        }
    }

    struct MinusOp: Parser.`Protocol`, Sendable {
        typealias Input = Substring.UTF8View
        typealias Output = Void
        typealias Failure = Parser.Match.Error

        func parse(_ input: inout Input) throws(Failure) -> Void {
            guard input.first == UInt8(ascii: "-") else {
                throw .predicateFailed(description: "-")
            }
            input.removeFirst()
        }
    }

    struct StarOp: Parser.`Protocol`, Sendable {
        typealias Input = Substring.UTF8View
        typealias Output = Void
        typealias Failure = Parser.Match.Error

        func parse(_ input: inout Input) throws(Failure) -> Void {
            guard input.first == UInt8(ascii: "*") else {
                throw .predicateFailed(description: "*")
            }
            input.removeFirst()
        }
    }

    @Test("ChainLeft - simple addition")
    func chainLeftAddition() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }

        var input = "1+2+3"[...].utf8
        let result = try parser.parse(&input)
        #expect(result == 6)  // (1+2)+3 = 6
    }

    @Test("ChainLeft - single operand")
    func chainLeftSingle() throws {
        let parser = IntAtom().chain.left(PlusOp()) { lhs, _, rhs in
            lhs + rhs
        }

        var input = "42"[...].utf8
        let result = try parser.parse(&input)
        #expect(result == 42)
    }
}
