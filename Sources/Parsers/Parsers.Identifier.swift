extension Parsers {

    public enum Identifier: Sendable {}
}

extension Parsers.Identifier {

    public struct CStyle: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parsers.Identifier.CStyle: Parsing {

    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Parsers.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        guard let first = input.first, Self.isStartChar(first) else {
            throw .predicateFailed(description: "identifier start character")
        }

        var count = 1
        input.removeFirst()

        while let byte = input.first, Self.isContinueChar(byte) {
            input.removeFirst()
            count += 1
        }

        return count
    }

    @inlinable
    package static func isStartChar(_ byte: UInt8) -> Bool {
        ASCII.Classification.isLetter(byte) || byte == .ascii.underline
    }

    @inlinable
    package static func isContinueChar(_ byte: UInt8) -> Bool {
        ASCII.Classification.isAlphanumeric(byte) || byte == .ascii.underline
    }
}

extension Parsers.Identifier {

    public struct Custom: Sendable {
        @usableFromInline
        let isStart: @Sendable (UInt8) -> Bool

        @usableFromInline
        let isContinue: @Sendable (UInt8) -> Bool

        @inlinable
        public init(
            start: @escaping @Sendable (UInt8) -> Bool,
            `continue`: @escaping @Sendable (UInt8) -> Bool
        ) {
            self.isStart = start
            self.isContinue = `continue`
        }
    }
}

extension Parsers.Identifier.Custom: Parsing {

    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Parsers.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        guard let first = input.first, isStart(first) else {
            throw .predicateFailed(description: "identifier start character")
        }

        var count = 1
        input.removeFirst()

        while let byte = input.first, isContinue(byte) {
            input.removeFirst()
            count += 1
        }

        return count
    }
}

extension Parsers {

    @inlinable
    public static var identifier: Identifier.Type { Identifier.self }
}
