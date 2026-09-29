extension Parser {

    public enum Whitespace: Sendable {}
}

extension Parser.Whitespace {

    public struct Horizontal: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Whitespace.Horizontal: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Parser.Constraint.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var count = 0

        while let byte = input.first,
            byte == .ascii.space || byte == .ascii.tab
        {
            input.removeFirst()
            count += 1
        }

        guard count > 0 else {
            throw .countTooLow(expected: 1, got: 0)
        }

        return count
    }
}

extension Parser.Whitespace {

    public struct Vertical: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Whitespace.Vertical: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Parser.Constraint.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var count = 0

        while let byte = input.first {
            if byte == .ascii.lf {
                input.removeFirst()
                count += 1
            } else if byte == .ascii.cr {
                input.removeFirst()
                count += 1

                if input.first == .ascii.lf {
                    input.removeFirst()
                }
            } else {
                break
            }
        }

        guard count > 0 else {
            throw .countTooLow(expected: 1, got: 0)
        }

        return count
    }
}

extension Parser.Whitespace {

    public struct `Any`: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Whitespace.`Any`: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Parser.Constraint.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var count = 0

        while let byte = input.first, Parser.Whitespace.isWhitespace(byte) {
            input.removeFirst()
            count += 1
        }

        guard count > 0 else {
            throw .countTooLow(expected: 1, got: 0)
        }

        return count
    }
}

extension Parser.Whitespace {

    public struct Skip: Sendable {

        public let kind: Kind

        @inlinable
        public init(kind: Kind = .any) {
            self.kind = kind
        }
    }
}

extension Parser.Whitespace.Skip {

    public enum Kind: Sendable {

        case horizontal

        case vertical

        case any
    }
}

extension Parser.Whitespace.Skip: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Never

    @inlinable
    public func parse(_ input: inout Input) {
        switch kind {
        case .horizontal:
            while let byte = input.first,
                byte == .ascii.space || byte == .ascii.tab
            {
                input.removeFirst()
            }

        case .vertical:
            while let byte = input.first {
                if byte == .ascii.lf {
                    input.removeFirst()
                } else if byte == .ascii.cr {
                    input.removeFirst()
                    if input.first == .ascii.lf {
                        input.removeFirst()
                    }
                } else {
                    break
                }
            }

        case .any:
            while let byte = input.first, Parser.Whitespace.isWhitespace(byte) {
                input.removeFirst()
            }
        }
    }
}

extension Parser.Whitespace {

    @inlinable
    package static func isWhitespace(_ byte: UInt8) -> Bool {
        ASCII.Classification.isWhitespace(byte)
    }
}

extension Parser {

    @inlinable
    public static var whitespace: Whitespace.Type { Whitespace.self }
}
