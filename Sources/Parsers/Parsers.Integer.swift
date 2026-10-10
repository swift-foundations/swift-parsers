extension Parsers {

    public enum Integer<Output: FixedWidthInteger> {}
}

extension Parsers.Integer {

    public enum Error: Swift.Error, Sendable, Equatable {

        case noDigits

        case overflow(String)

        case invalidDigit(character: UInt8, base: Int)

        case missingPrefix(expected: String)
    }
}

extension Parsers.Integer {

    public struct Decimal: Sendable {

        public let allowSign: Bool

        public let allowLeadingZeros: Bool

        @inlinable
        public init(
            allowSign: Bool = true,
            allowLeadingZeros: Bool = true
        ) {
            self.allowSign = allowSign
            self.allowLeadingZeros = allowLeadingZeros
        }
    }
}

extension Parsers.Integer.Decimal: Parsing {

    public typealias Input = Substring.UTF8View
    public typealias Failure = Parsers.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var isNegative = false

        if allowSign {
            if let first = input.first {
                if first == .ascii.hyphen {
                    isNegative = true
                    input.removeFirst()
                } else if first == .ascii.plus {
                    input.removeFirst()
                }
            }
        }

        var hasDigits = false
        var result: Output = 0
        var digitString = ""

        if !allowLeadingZeros {
            while input.first == .ascii.0 {
                hasDigits = true
                input.removeFirst()
                if input.first.map({ $0 < .ascii.0 || $0 > .ascii.9 }) ?? true {

                    return 0
                }
            }
        }

        while let byte = input.first, byte >= .ascii.0, byte <= .ascii.9 {
            hasDigits = true
            let digit = Output(byte - .ascii.0)
            digitString.append(Character(UnicodeScalar(byte)))

            let (multiplied, overflow1) = result.multipliedReportingOverflow(by: 10)
            guard !overflow1 else {
                throw .overflow(digitString)
            }

            let (added, overflow2) =
                isNegative
                ? multiplied.subtractingReportingOverflow(digit)
                : multiplied.addingReportingOverflow(digit)
            guard !overflow2 else {
                throw .overflow(digitString)
            }

            result = added
            input.removeFirst()
        }

        guard hasDigits else {
            throw .noDigits
        }

        return result
    }
}

extension Parsers.Integer {

    public struct Hexadecimal: Sendable {

        public let requirePrefix: Bool

        @inlinable
        public init(requirePrefix: Bool = false) {
            self.requirePrefix = requirePrefix
        }
    }
}

extension Parsers.Integer.Hexadecimal: Parsing {

    public typealias Input = Substring.UTF8View
    public typealias Failure = Parsers.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        var hasPrefix = false
        if input.first == .ascii.0 {
            var copy = input
            copy.removeFirst()
            if let second = copy.first, second == .ascii.x || second == .ascii.X {
                hasPrefix = true
                input = copy
                input.removeFirst()
            }
        }

        if requirePrefix && !hasPrefix {
            throw .missingPrefix(expected: "0x")
        }

        var hasDigits = false
        var result: Output = 0
        var digitString = ""

        while let byte = input.first {
            let digit: Output
            if byte >= .ascii.0 && byte <= .ascii.9 {
                digit = Output(byte - .ascii.0)
            } else if byte >= .ascii.a && byte <= .ascii.f {
                digit = Output(byte - .ascii.a + 10)
            } else if byte >= .ascii.A && byte <= .ascii.F {
                digit = Output(byte - .ascii.A + 10)
            } else {
                break
            }

            hasDigits = true
            digitString.append(Character(UnicodeScalar(byte)))

            let (multiplied, overflow1) = result.multipliedReportingOverflow(by: 16)
            guard !overflow1 else {
                throw .overflow(digitString)
            }

            let (added, overflow2) = multiplied.addingReportingOverflow(digit)
            guard !overflow2 else {
                throw .overflow(digitString)
            }

            result = added
            input.removeFirst()
        }

        guard hasDigits else {
            throw .noDigits
        }

        return result
    }
}

extension Parsers.Integer {

    public struct Binary: Sendable {

        public let requirePrefix: Bool

        @inlinable
        public init(requirePrefix: Bool = false) {
            self.requirePrefix = requirePrefix
        }
    }
}

extension Parsers.Integer.Binary: Parsing {

    public typealias Input = Substring.UTF8View
    public typealias Failure = Parsers.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        var hasPrefix = false
        if input.first == .ascii.0 {
            var copy = input
            copy.removeFirst()
            if let second = copy.first, second == .ascii.b || second == .ascii.B {
                hasPrefix = true
                input = copy
                input.removeFirst()
            }
        }

        if requirePrefix && !hasPrefix {
            throw .missingPrefix(expected: "0b")
        }

        var hasDigits = false
        var result: Output = 0

        while let byte = input.first, byte == .ascii.0 || byte == .ascii.1 {
            hasDigits = true
            let digit = Output(byte - .ascii.0)

            let (shifted, overflow1) = result.multipliedReportingOverflow(by: 2)
            guard !overflow1 else {
                throw .overflow("binary overflow")
            }

            let (added, overflow2) = shifted.addingReportingOverflow(digit)
            guard !overflow2 else {
                throw .overflow("binary overflow")
            }

            result = added
            input.removeFirst()
        }

        guard hasDigits else {
            throw .noDigits
        }

        return result
    }
}

extension Parsers.Integer {

    public struct Octal: Sendable {

        public let requirePrefix: Bool

        @inlinable
        public init(requirePrefix: Bool = false) {
            self.requirePrefix = requirePrefix
        }
    }
}

extension Parsers.Integer.Octal: Parsing {

    public typealias Input = Substring.UTF8View
    public typealias Failure = Parsers.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {

        var hasPrefix = false
        if input.first == .ascii.0 {
            var copy = input
            copy.removeFirst()
            if let second = copy.first, second == .ascii.o || second == .ascii.O {
                hasPrefix = true
                input = copy
                input.removeFirst()
            }
        }

        if requirePrefix && !hasPrefix {
            throw .missingPrefix(expected: "0o")
        }

        var hasDigits = false
        var result: Output = 0

        while let byte = input.first, byte >= .ascii.0, byte <= .ascii.7 {
            hasDigits = true
            let digit = Output(byte - .ascii.0)

            let (multiplied, overflow1) = result.multipliedReportingOverflow(by: 8)
            guard !overflow1 else {
                throw .overflow("octal overflow")
            }

            let (added, overflow2) = multiplied.addingReportingOverflow(digit)
            guard !overflow2 else {
                throw .overflow("octal overflow")
            }

            result = added
            input.removeFirst()
        }

        guard hasDigits else {
            throw .noDigits
        }

        return result
    }
}

extension Parsers {

    @inlinable
    public static func integer<T: FixedWidthInteger>(
        _ type: T.Type = Int.self
    ) -> Integer<T>.Type {
        Integer<T>.self
    }
}
