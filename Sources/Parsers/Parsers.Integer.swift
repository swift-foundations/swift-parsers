//
//  Parser.Integer.swift
//  swift-parsing
//
//  Integer parsers for common numeric formats.
//
//  ## Design
//
//  Integer parsers are generic over FixedWidthInteger, allowing parsing into
//  any Swift integer type (Int, Int32, UInt64, etc.). Each format (decimal,
//  hexadecimal, binary, octal) is a separate struct for type safety.
//
//  ## Usage
//
//  ```swift
//  // Parse a decimal integer
//  let parser = Parser.Integer<Int>.Decimal()
//  var input = "123"[...].utf8
//  let value = try parser.parse(&input)  // 123
//
//  // Parse hexadecimal with prefix
//  let hex = Parser.Integer<UInt32>.Hexadecimal(requirePrefix: true)
//  var input2 = "0xFF"[...].utf8
//  let value2 = try hex.parse(&input2)  // 255
//  ```
//

extension Parser {
    /// Namespace for integer parsing types.
    ///
    /// Provides parsers for decimal, hexadecimal, binary, and octal integers
    /// with configurable options for signs, prefixes, and leading zeros.
    public enum Integer<Output: FixedWidthInteger> {}
}

// MARK: - Error Type

extension Parser.Integer {
    /// Errors specific to integer parsing.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// No digits found at all.
        case noDigits

        /// The parsed value overflows the target integer type.
        ///
        /// - Parameter overflow: String representation of the overflowing value
        case overflow(String)

        /// Invalid digit for the expected base.
        ///
        /// - Parameters:
        ///   - character: The invalid character found
        ///   - base: The expected numeric base (10, 16, 2, 8)
        case invalidDigit(character: UInt8, base: Int)

        /// Required prefix was missing.
        ///
        /// - Parameter expected: The expected prefix, such as "0x" or "0b"
        case missingPrefix(expected: String)
    }
}

// MARK: - Decimal Parser

extension Parser.Integer {
    /// Parses decimal (base-10) integers.
    ///
    /// Supports optional sign prefix (+/-), with configurable leading zeros.
    ///
    /// ## Grammar
    ///
    /// ```
    /// decimal = [sign] digit+
    /// sign    = "+" | "-"
    /// digit   = "0"..."9"
    /// ```
    ///
    /// ## Examples
    ///
    /// ```swift
    /// // Basic usage
    /// let parser = Parser.Integer<Int>.Decimal()
    /// try parser.parse("123")      // 123
    /// try parser.parse("-456")     // -456
    /// try parser.parse("+789")     // 789
    ///
    /// // Unsigned integers
    /// let unsigned = Parser.Integer<UInt>.Decimal(allowSign: false)
    /// try unsigned.parse("123")    // 123
    /// try unsigned.parse("-1")     // throws: no digits (- not recognized)
    /// ```
    public struct Decimal: Sendable {
        /// Whether to parse optional +/- prefix.
        public let allowSign: Bool

        /// Whether to allow leading zeros, such as "007".
        public let allowLeadingZeros: Bool

        /// Creates a decimal integer parser.
        ///
        /// - Parameters:
        ///   - allowSign: Parse optional +/- prefix. Default `true`.
        ///   - allowLeadingZeros: Allow leading zeros. Default `true`.
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

extension Parser.Integer.Decimal: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Failure = Parser.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        var isNegative = false

        // Parse optional sign
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

        // Track if we parsed any digits
        var hasDigits = false
        var result: Output = 0
        var digitString = ""

        // Skip leading zeros if not allowed (but keep at least one)
        if !allowLeadingZeros {
            while input.first == .ascii.0 {
                hasDigits = true
                input.removeFirst()
                if input.first.map({ $0 < .ascii.0 || $0 > .ascii.9 }) ?? true {
                    // This was the only digit or next char is not a digit
                    return 0
                }
            }
        }

        // Parse digits
        while let byte = input.first, byte >= .ascii.0, byte <= .ascii.9 {
            hasDigits = true
            let digit = Output(byte - .ascii.0)
            digitString.append(Character(UnicodeScalar(byte)))

            // Check for overflow before multiplication
            let (multiplied, overflow1) = result.multipliedReportingOverflow(by: 10)
            guard !overflow1 else {
                throw .overflow(digitString)
            }

            // Check for overflow before addition
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

// MARK: - Hexadecimal Parser

extension Parser.Integer {
    /// Parses hexadecimal (base-16) integers.
    ///
    /// Supports optional "0x" or "0X" prefix, case-insensitive digits.
    ///
    /// ## Grammar
    ///
    /// ```
    /// hex    = [prefix] hexdigit+
    /// prefix = "0x" | "0X"
    /// hexdigit = "0"..."9" | "a"..."f" | "A"..."F"
    /// ```
    public struct Hexadecimal: Sendable {
        /// Whether to require "0x" prefix.
        public let requirePrefix: Bool

        /// Creates a hexadecimal integer parser.
        ///
        /// - Parameter requirePrefix: Require "0x" prefix. Default `false`.
        @inlinable
        public init(requirePrefix: Bool = false) {
            self.requirePrefix = requirePrefix
        }
    }
}

extension Parser.Integer.Hexadecimal: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Failure = Parser.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Check for prefix
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

        // Parse hex digits
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

            // Check for overflow
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

// MARK: - Binary Parser

extension Parser.Integer {
    /// Parses binary (base-2) integers.
    ///
    /// Supports optional "0b" or "0B" prefix.
    ///
    /// ## Grammar
    ///
    /// ```
    /// binary = [prefix] bindigit+
    /// prefix = "0b" | "0B"
    /// bindigit = "0" | "1"
    /// ```
    public struct Binary: Sendable {
        /// Whether to require "0b" prefix.
        public let requirePrefix: Bool

        /// Creates a binary integer parser.
        ///
        /// - Parameter requirePrefix: Require "0b" prefix. Default `false`.
        @inlinable
        public init(requirePrefix: Bool = false) {
            self.requirePrefix = requirePrefix
        }
    }
}

extension Parser.Integer.Binary: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Failure = Parser.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Check for prefix
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

        // Parse binary digits
        var hasDigits = false
        var result: Output = 0

        while let byte = input.first, byte == .ascii.0 || byte == .ascii.1 {
            hasDigits = true
            let digit = Output(byte - .ascii.0)

            // Check for overflow
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

// MARK: - Octal Parser

extension Parser.Integer {
    /// Parses octal (base-8) integers.
    ///
    /// Supports optional "0o" or "0O" prefix.
    ///
    /// ## Grammar
    ///
    /// ```
    /// octal  = [prefix] octdigit+
    /// prefix = "0o" | "0O"
    /// octdigit = "0"..."7"
    /// ```
    public struct Octal: Sendable {
        /// Whether to require "0o" prefix.
        public let requirePrefix: Bool

        /// Creates an octal integer parser.
        ///
        /// - Parameter requirePrefix: Require "0o" prefix. Default `false`.
        @inlinable
        public init(requirePrefix: Bool = false) {
            self.requirePrefix = requirePrefix
        }
    }
}

extension Parser.Integer.Octal: Parser.`Protocol` {
    public typealias Input = Substring.UTF8View
    public typealias Failure = Parser.Integer<Output>.Error

    @inlinable
    public func parse(_ input: inout Input) throws(Failure) -> Output {
        // Check for prefix
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

        // Parse octal digits
        var hasDigits = false
        var result: Output = 0

        while let byte = input.first, byte >= .ascii.0, byte <= .ascii.7 {
            hasDigits = true
            let digit = Output(byte - .ascii.0)

            // Check for overflow
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

// MARK: - Convenience Accessors

extension Parser {
    /// Access to integer parsers via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.integer(Int.self).Decimal()
    /// Parser.integer(UInt32.self).Hexadecimal(requirePrefix: true)
    /// ```
    @inlinable
    public static func integer<T: FixedWidthInteger>(
        _ type: T.Type = Int.self
    ) -> Integer<T>.Type {
        Integer<T>.self
    }
}
