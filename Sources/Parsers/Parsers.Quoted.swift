extension Parsers {

    public enum Quoted: Sendable {}
}

extension Parsers.Quoted {

    public enum EscapeStyle: Sendable {

        case backslash

        case doubling

        case none
    }
}

extension Parsers.Quoted {

    public enum Error: Swift.Error, Sendable, Equatable {

        case missingOpenQuote

        case unterminatedString

        case invalidEscape(sequence: String)

        case unexpectedNewline
    }
}

extension Parsers.Quoted {

    public struct Double: Sendable {

        public let allowNewlines: Bool

        @inlinable
        public init(allowNewlines: Bool = false) {
            self.allowNewlines = allowNewlines
        }
    }
}

extension Parsers.Quoted.Double: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parsers.Quoted.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        guard input.first == .ascii.doubleQuote else {
            throw .missingOpenQuote
        }
        input.removeFirst()

        var result: [UInt8] = []

        while let byte = input.first {
            if byte == .ascii.doubleQuote {

                input.removeFirst()
                return String(decoding: result, as: UTF8.self)
            } else if byte == .ascii.backslash {

                input.removeFirst()
                guard let escaped = input.first else {
                    throw .unterminatedString
                }
                input.removeFirst()

                switch escaped {
                case .ascii.backslash: result.append(.ascii.backslash)
                case .ascii.doubleQuote: result.append(.ascii.doubleQuote)
                case .ascii.n: result.append(.ascii.lf)
                case .ascii.r: result.append(.ascii.cr)
                case .ascii.t: result.append(.ascii.tab)
                case .ascii.0: result.append(.ascii.nul)
                case .ascii.b: result.append(.ascii.bs)
                case .ascii.f: result.append(.ascii.ff)

                default:
                    throw .invalidEscape(sequence: "\\" + String(UnicodeScalar(escaped)))
                }
            } else if byte == .ascii.lf || byte == .ascii.cr {

                if allowNewlines {
                    result.append(byte)
                    input.removeFirst()
                } else {
                    throw .unexpectedNewline
                }
            } else {
                result.append(byte)
                input.removeFirst()
            }
        }

        throw .unterminatedString
    }
}

extension Parsers.Quoted {

    public struct Single: Sendable {

        public let allowNewlines: Bool

        @inlinable
        public init(allowNewlines: Bool = false) {
            self.allowNewlines = allowNewlines
        }
    }
}

extension Parsers.Quoted.Single: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parsers.Quoted.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        guard input.first == .ascii.apostrophe else {
            throw .missingOpenQuote
        }
        input.removeFirst()

        var result: [UInt8] = []

        while let byte = input.first {
            if byte == .ascii.apostrophe {

                input.removeFirst()
                return String(decoding: result, as: UTF8.self)
            } else if byte == .ascii.lf || byte == .ascii.cr {

                if allowNewlines {
                    result.append(byte)
                    input.removeFirst()
                } else {
                    throw .unexpectedNewline
                }
            } else {
                result.append(byte)
                input.removeFirst()
            }
        }

        throw .unterminatedString
    }
}

extension Parsers.Quoted {

    public struct Doubling: Sendable {

        public let quote: UInt8

        @inlinable
        public init(quote: UInt8 = .ascii.doubleQuote) {
            self.quote = quote
        }
    }
}

extension Parsers.Quoted.Doubling: Parsing {
    public typealias Input = Substring.UTF8View
    public typealias Output = String
    public typealias Failure = Parsers.Quoted.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        guard input.first == quote else {
            throw .missingOpenQuote
        }
        input.removeFirst()

        var result: [UInt8] = []

        while let byte = input.first {
            if byte == quote {
                input.removeFirst()

                if input.first == quote {
                    result.append(quote)
                    input.removeFirst()
                } else {

                    return String(decoding: result, as: UTF8.self)
                }
            } else {
                result.append(byte)
                input.removeFirst()
            }
        }

        throw .unterminatedString
    }
}

extension Parsers {

    @inlinable
    public static var quoted: Quoted.Type { Quoted.self }
}
