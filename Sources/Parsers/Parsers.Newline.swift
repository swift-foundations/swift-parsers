extension Parsers {

    public enum Newline: Sendable {}
}

extension Parsers.Newline {

    public struct LF: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parsers.Newline.LF: Parsing {
    public var body: Never {
        borrowing get {
            return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
        }
    }

    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parsers.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) {
        guard input.first == .ascii.lf else {
            throw .predicateFailed(description: "LF (\\n)")
        }
        input.removeFirst()
    }
}

extension Parsers.Newline {

    public struct CR: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parsers.Newline.CR: Parsing {
    public var body: Never {
        borrowing get {
            return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
        }
    }

    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parsers.Match.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) {
        guard input.first == .ascii.cr else {
            throw .predicateFailed(description: "CR (\\r)")
        }
        input.removeFirst()
    }
}

extension Parsers.Newline {

    public struct CRLF: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parsers.Newline.CRLF: Parsing {
    public var body: Never {
        borrowing get {
            return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
        }
    }

    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parsers.Match.Error

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

extension Parsers.Newline {

    public struct `Any`: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parsers.Newline.`Any`: Parsing {
    public var body: Never {
        borrowing get {
            return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
        }
    }

    public typealias Input = Substring.UTF8View
    public typealias Output = Void
    public typealias Failure = Parsers.Match.Error

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

extension Parsers.Newline {

    public struct Line: Sendable {
        @inlinable
        public init() {}
    }
}

extension Parsers.Newline.Line: Parsing {
    public var body: Never {
        borrowing get {
            return fatalError("\(Self.self) is a leaf: implement its conformance requirements directly")
        }
    }

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

extension Parsers {

    @inlinable
    public static var newline: Newline.Type { Newline.self }
}
