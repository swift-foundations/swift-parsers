//
//  Parser.Diagnostic.swift
//  swift-parsing
//
//  Error formatting and diagnostic generation.
//
//  ## Design
//
//  Diagnostics transform raw parse errors into human-readable messages
//  with source context. This module provides:
//
//  - Source location tracking (line, column)
//  - Multiple formatting styles (compact, expanded, caret)
//  - Rich error messages with source snippets
//
//  ## Usage
//
//  ```swift
//  let source = Parser.Diagnostic.Source(content: sourceCode, filename: "input.txt")
//
//  do {
//      _ = try parser.parse(input)
//  } catch let error as Parser.Error.Located<_> {
//      print(error.formatted(in: source, style: .expanded()))
//  }
//  ```
//

extension Parser {
    /// Namespace for diagnostic types.
    public enum Diagnostic: Sendable {}
}

// MARK: - Source

extension Parser.Diagnostic {
    /// Represents source content for error reporting.
    public struct Source: Sendable {
        /// The original source content.
        public let content: String

        /// Optional filename for error messages.
        public let filename: String?

        /// Line start indices for fast line lookup.
        @usableFromInline
        let lineStarts: [String.Index]

        /// Creates a source from content.
        ///
        /// - Parameters:
        ///   - content: The source text.
        ///   - filename: Optional filename.
        public init(content: String, filename: String? = nil) {
            self.content = content
            self.filename = filename

            // Pre-compute line start indices via UTF-8 byte scan.
            // Newline (0x0A) is a single-byte scalar, so every recorded
            // index is both a UTF-8 boundary and a Character boundary.
            var starts: [String.Index] = [content.startIndex]
            let utf8 = content.utf8
            var pos = utf8.startIndex
            while pos < utf8.endIndex {
                if utf8[pos] == 0x0A {
                    let next = utf8.index(after: pos)
                    if next < utf8.endIndex {
                        starts.append(next)
                    }
                }
                pos = utf8.index(after: pos)
            }
            self.lineStarts = starts
        }
    }
}

extension Parser.Diagnostic.Source {
    /// Computes the source location for a text position.
    ///
    /// - Parameter offset: Text position (0-indexed).
    /// - Returns: Source location with file identity, line, and column.
    public func location(at offset: Text.Position) -> Source_Primitives.Source.Location {
        let rawOffset = Int(bitPattern: offset)
        let targetIndex = content.utf8.index(content.utf8.startIndex, offsetBy: min(rawOffset, content.utf8.count))

        // Binary search for line
        var lo = 0
        var hi = lineStarts.count - 1

        while lo < hi {
            let mid = (lo + hi + 1) / 2
            if lineStarts[mid] <= targetIndex {
                lo = mid
            } else {
                hi = mid - 1
            }
        }

        let lineNumber = lo + 1  // 1-indexed
        let lineStart = lineStarts[lo]
        let column = content.utf8.distance(from: lineStart, to: targetIndex) + 1  // 1-indexed, byte offset

        return Source_Primitives.Source.Location(
            fileID: filename ?? "",
            line: lineNumber,
            column: column
        )
    }

    /// Returns the content of a specific line.
    ///
    /// - Parameter lineNumber: 1-indexed line number.
    /// - Returns: The line content (without newline).
    public func line(_ lineNumber: Int) -> String? {
        guard lineNumber >= 1 && lineNumber <= lineStarts.count else {
            return nil
        }

        let idx = lineNumber - 1
        let start = lineStarts[idx]
        let end: String.Index

        if idx + 1 < lineStarts.count {
            // Next line exists
            end = content.index(before: lineStarts[idx + 1])
        } else {
            end = content.endIndex
        }

        if start >= end {
            return ""
        }

        return String(content[start..<end])
    }
}

// MARK: - Style

extension Parser.Diagnostic {
    /// Formatting style for diagnostics.
    public enum Style: Sendable {
        /// Compact single-line format.
        /// Example: `error at offset 42: unexpected character`
        case compact

        /// Expanded format with source context.
        /// Shows surrounding lines with line numbers.
        case expanded(contextLines: Int = 2)

        /// Caret format pointing to error location.
        /// Shows single line with ^ marker.
        case caret

        /// Rich format with all information.
        case rich
    }
}

// MARK: - Formatter

extension Parser.Diagnostic {
    /// Formats an error with source context.
    ///
    /// - Parameters:
    ///   - error: The error to format.
    ///   - source: Source content for context.
    ///   - style: Formatting style.
    /// - Returns: Formatted diagnostic string.
    public static func format<E: Swift.Error>(
        _ error: E,
        at offset: Text.Position,
        in source: Source,
        style: Style = .expanded()
    ) -> String {
        let location = source.location(at: offset)
        let errorMessage = String(describing: error)

        switch style {
        case .compact:
            return formatCompact(error: errorMessage, location: location, source: source)

        case .expanded(let contextLines):
            return formatExpanded(error: errorMessage, location: location, source: source, contextLines: contextLines)

        case .caret:
            return formatCaret(error: errorMessage, location: location, source: source)

        case .rich:
            return formatRich(error: errorMessage, location: location, offset: offset, source: source)
        }
    }

    @usableFromInline
    static func padLeft(_ string: String, toLength length: Int) -> String {
        if string.count >= length {
            return string
        }
        return String(repeating: " ", count: length - string.count) + string
    }

    @usableFromInline
    static func formatCompact(error: String, location: Source_Primitives.Source.Location, source: Source) -> String {
        if let filename = source.filename {
            return "\(filename):\(location.line):\(location.column): error: \(error)"
        } else {
            return "error at \(location.line):\(location.column): \(error)"
        }
    }

    @usableFromInline
    static func formatExpanded(error: String, location: Source_Primitives.Source.Location, source: Source, contextLines: Int) -> String {
        // `Source.Location.line` is typed `Text.Line.Number`; arithmetic
        // with `Int`-typed offsets / lookups in `source.lineStarts` go
        // through `.underlying` once at the formatter boundary per
        // H.4 cascade guidance.
        let lineInt: Int = Int(location.line.underlying)
        var lines: [String] = []

        // Header
        if let filename = source.filename {
            lines.append("error: \(error)")
            lines.append("  --> \(filename):\(location.line):\(location.column)")
        } else {
            lines.append("error: \(error)")
            lines.append("  --> line \(location.line), column \(location.column)")
        }
        lines.append("   |")

        // Context lines before
        let startLine = max(1, lineInt - contextLines)
        let endLine = min(source.lineStarts.count, lineInt + contextLines)

        for lineNum in startLine...endLine {
            guard let lineContent = source.line(lineNum) else { continue }

            let lineNumStr = padLeft(String(lineNum), toLength: 3)

            if lineNum == lineInt {
                lines.append(" \(lineNumStr)| \(lineContent)")
                // Caret line
                let spaces = String(repeating: " ", count: location.column - 1)
                lines.append("   | \(spaces)^")
            } else {
                lines.append(" \(lineNumStr)| \(lineContent)")
            }
        }

        lines.append("   |")
        return lines.joined(separator: "\n")
    }

    @usableFromInline
    static func formatCaret(error: String, location: Source_Primitives.Source.Location, source: Source) -> String {
        // Convert at the `Source.line(_:)` boundary per H.4 cascade
        // guidance — `Source` is the stdlib-Int-shaped consumer here.
        guard let lineContent = source.line(Int(location.line.underlying)) else {
            return formatCompact(error: error, location: location, source: source)
        }

        let spaces = String(repeating: " ", count: location.column - 1)

        return """
        \(lineContent)
        \(spaces)^ error: \(error)
        """
    }

    @usableFromInline
    static func formatRich(error: String, location: Source_Primitives.Source.Location, offset: Text.Position, source: Source) -> String {
        // See `formatExpanded` — `.underlying` conversion at formatter boundary
        // per H.4 cascade guidance.
        let lineInt: Int = Int(location.line.underlying)
        var lines: [String] = []

        // Header with filename
        lines.append("================================================================================")
        if let filename = source.filename {
            lines.append("ERROR in \(filename) at line \(location.line), column \(location.column)")
        } else {
            lines.append("ERROR at line \(location.line), column \(location.column), offset \(offset)")
        }
        lines.append("================================================================================")
        lines.append("")
        lines.append(error)
        lines.append("")

        // Context with 3 lines
        let startLine = max(1, lineInt - 3)
        let endLine = min(source.lineStarts.count, lineInt + 3)

        for lineNum in startLine...endLine {
            guard let lineContent = source.line(lineNum) else { continue }

            let marker = lineNum == lineInt ? ">>>" : "   "
            lines.append("\(marker) \(lineNum): \(lineContent)")

            if lineNum == lineInt {
                let spaces = String(repeating: " ", count: String(lineNum).count + 5 + location.column)
                lines.append("\(spaces)^^^")
            }
        }

        lines.append("")
        lines.append("================================================================================")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Error Extension

extension Parser.Error.Located {
    /// Formats this located error with source context.
    ///
    /// - Parameters:
    ///   - source: Source content.
    ///   - style: Formatting style.
    /// - Returns: Formatted diagnostic string.
    public func formatted(
        in source: Parser.Diagnostic.Source,
        style: Parser.Diagnostic.Style = .expanded()
    ) -> String {
        Parser.Diagnostic.format(self, at: offset, in: source, style: style)
    }
}

// MARK: - Convenience Accessors

extension Parser {
    /// Access to diagnostic types via nested accessor pattern.
    ///
    /// Usage:
    /// ```swift
    /// Parser.diagnostic.Source(content: ...)
    /// Parser.diagnostic.format(error, at: offset, in: source)
    /// ```
    @inlinable
    public static var diagnostic: Diagnostic.Type { Diagnostic.self }
}
