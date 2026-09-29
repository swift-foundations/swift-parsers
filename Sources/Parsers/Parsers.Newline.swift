extension Parser {

    public enum Newline: Sendable {}
}

extension Parser.Newline {

    public struct LF: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.LF: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) {
        guard input.first == .ascii.lf else {
            throw .predicateFailed(description: "LF (\\n)")
        }
        input.removeFirst()
    }
}

extension Parser.Newline {

    public struct CR: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.CR: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) {
        guard input.first == .ascii.cr else {
            throw .predicateFailed(description: "CR (\\r)")
        }
        input.removeFirst()
    }
}

extension Parser.Newline {

    public struct CRLF: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.CRLF: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) {
        guard input.first == .ascii.cr else {
            throw .predicateFailed(description: "CRLF (\\r\\n)")
        }

        var copy = input
        copy.removeFirst()

        guard copy.first == .ascii.lf else {
            throw .predicateFailed(description: "CRLF (\\r\\n)")
        }

        input = copy
        input.removeFirst()
    }
}

extension Parser.Newline {

    public struct `Any`: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.`Any`: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parser.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) {
        guard let first = input.first else {
            throw .predicateFailed(description: "newline")
        }

        if first == .ascii.cr {

            input.removeFirst()
            if input.first == .ascii.lf {
                input.removeFirst()
            }

        } else if first == .ascii.lf {
            input.removeFirst()
        } else {
            throw .predicateFailed(description: "newline")
        }
    }
}

extension Parser.Newline {

    public struct Line: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parser.Newline.Line: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = Int
    public typealias Failure = Never

    @inlinable
    public func parse(_ input: inout Input) -> Output {
        var count = 0

        while let byte = input.first, byte != .ascii.lf, byte != .ascii.cr {
            input.removeFirst()
            count += 1
        }

        return count
    }
}

extension Parser {

    @inlinable
    public static var newline: Newline.Type { Newline.self }
}
