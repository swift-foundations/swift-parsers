import Parsers_Test_Support
import Testing

@Suite
struct `Parsers - progress guards` {

    final class Calls {
        var count = 0
    }

    struct Budgeted: Parsing {
        typealias Input = Substring.UTF8View
        typealias Output = Void
        typealias Failure = Parsers.Match.Error

        let calls: Calls

        func parse(_ input: inout Input) throws(Failure) {
            calls.count += 1
            guard calls.count <= 50 else {
                throw .predicateFailed(description: "budget")
            }
        }
    }

    struct Digit: Parsing {
        typealias Input = Substring.UTF8View
        typealias Output = Int
        typealias Failure = Parsers.Match.Error

        let nullable: Bool

        func parse(_ input: inout Input) throws(Failure) -> Int {
            guard let byte = input.first, byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
                guard nullable else { throw .predicateFailed(description: "digit") }
                return 0
            }
            input.removeFirst()
            return Int(byte - UInt8(ascii: "0"))
        }
    }

    struct Plus: Parsing {
        typealias Input = Substring.UTF8View
        typealias Output = Void
        typealias Failure = Parsers.Match.Error

        func parse(_ input: inout Input) throws(Failure) {
            guard input.first == UInt8(ascii: "+") else { throw .predicateFailed(description: "+") }
            input.removeFirst()
        }
    }

    @Test
    func `left chain stops when an empty operator and a nullable operand consume nothing`() throws {
        let calls = Calls()
        var input = "7"[...].utf8
        let result = try Digit(nullable: true).chain.left(Budgeted(calls: calls)) { a, _, b in a + b }.parse(&input)
        #expect(result == 7)
        #expect(input.isEmpty)
        #expect(calls.count == 1)
    }

    @Test
    func `right chain stops recursing when its frame has not advanced`() throws {
        let calls = Calls()
        var input = "7"[...].utf8
        let result = try Digit(nullable: true).chain.right(Budgeted(calls: calls)) { a, _, b in a + b }.parse(&input)
        #expect(result == 7)
        #expect(input.isEmpty)
        #expect(calls.count == 2)
    }

    @Test
    func `empty operators with consuming operands stay valid and keep associativity`() throws {
        var left = "123"[...].utf8
        #expect(try Digit(nullable: false).chain.left(Budgeted(calls: Calls())) { a, _, b in a - b }.parse(&left) == -4)
        var right = "123"[...].utf8
        #expect(try Digit(nullable: false).chain.right(Budgeted(calls: Calls())) { a, _, b in a - b }.parse(&right) == 2)
    }

    @Test
    func `a failed right-hand side rolls back to before the operator`() throws {
        var input = "1+"[...].utf8
        #expect(try Digit(nullable: false).chain.left(Plus()) { a, _, b in a + b }.parse(&input) == 1)
        #expect(Array(input) == Array("+".utf8))
    }

    static func climbing(
        atom: Digit,
        calls: Calls,
        associativity: Parsers.Expression.Associativity,
        prefix: Bool = false
    ) -> Parsers.Expression.Climbing<Digit, Budgeted> {
        Parsers.Expression.Climbing(
            atom: atom,
            operators: [
                .init(parser: Budgeted(calls: calls), precedence: 1, associativity: associativity) { a, b in a - b }
            ],
            prefix: prefix ? [.init(parser: Budgeted(calls: calls)) { -$0 }] : []
        )
    }

    @Test(arguments: [Parsers.Expression.Associativity.left, .right, .none])
    func `expression stops when an empty operator and a nullable atom consume nothing`(
        _ associativity: Parsers.Expression.Associativity
    ) throws {
        let calls = Calls()
        var input = "7"[...].utf8
        let result = try Self.climbing(atom: Digit(nullable: true), calls: calls, associativity: associativity).parse(&input)
        #expect(result == 7)
        #expect(input.isEmpty)
        #expect(calls.count <= 3)
    }

    @Test
    func `expression with an empty operator and consuming atoms keeps precedence climbing`() throws {
        var left = "123"[...].utf8
        #expect(try Self.climbing(atom: Digit(nullable: false), calls: Calls(), associativity: .left).parse(&left) == -4)
        var right = "123"[...].utf8
        #expect(try Self.climbing(atom: Digit(nullable: false), calls: Calls(), associativity: .right).parse(&right) == 2)
    }

    @Test
    func `an empty prefix operator is skipped instead of recursing`() throws {
        let calls = Calls()
        var input = "7"[...].utf8
        let result = try Parsers.Expression.Climbing(
            atom: Digit(nullable: false),
            operators: [Parsers.Expression.Operator<Int, Budgeted>](),
            prefix: [.init(parser: Budgeted(calls: calls)) { -$0 }]
        ).parse(&input)
        #expect(result == 7)
        #expect(calls.count == 1)
    }
}
