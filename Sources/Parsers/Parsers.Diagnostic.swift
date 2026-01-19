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

extension Parsers {
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

            // Pre-compute line start indices
            var starts: [String.Index] = [content.startIndex]
            for (index, char) in content.enumerated() {
                if char == "\n" {
                    let idx = content.index(content.startIndex, offsetBy: index + 1)
                    if idx < content.endIndex {
                        starts.append(idx)
                    }
                }
            }
            self.lineStarts = starts
        }
    }
}

// MARK: - Location

extension Parser.Diagnostic {
    /// A location within source content.
    public struct Location: Sendable, Equatable {
        /// 1-indexed line number.
        public let line: Int

        /// 1-indexed column number.
        public let column: Int

        /// 0-indexed byte offset.
        public let offset: Int

        @inlinable
        public init(line: Int, column: Int, offset: Int) {
            self.line = line
            self.column = column
            self.offset = offset
        }
    }
}

extension Parser.Diagnostic.Source {
    /// Computes the location for a byte offset.
    ///
    /// - Parameter offset: Byte offset (0-indexed).
    /// - Returns: Location with line and column.
    public func location(at offset: Int) -> Parser.Diagnostic.Location {
        let targetIndex = content.utf8.index(content.utf8.startIndex, offsetBy: min(offset, content.utf8.count))

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
        let column = content.distance(from: lineStart, to: targetIndex) + 1  // 1-indexed

        return Parser.Diagnostic.Location(line: lineNumber, column: column, offset: offset)
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
    public static func format<E: Error>(
        _ error: E,
        at offset: Int,
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
            return formatRich(error: errorMessage, location: location, source: source)
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
    static func formatCompact(error: String, location: Location, source: Source) -> String {
        if let filename = source.filename {
            return "\(filename):\(location.line):\(location.column): error: \(error)"
        } else {
            return "error at \(location.line):\(location.column): \(error)"
        }
    }

    @usableFromInline
    static func formatExpanded(error: String, location: Location, source: Source, contextLines: Int) -> String {
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
        let startLine = max(1, location.line - contextLines)
        let endLine = min(source.lineStarts.count, location.line + contextLines)

        for lineNum in startLine...endLine {
            guard let lineContent = source.line(lineNum) else { continue }

            let lineNumStr = padLeft(String(lineNum), toLength: 3)

            if lineNum == location.line {
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
    static func formatCaret(error: String, location: Location, source: Source) -> String {
        guard let lineContent = source.line(location.line) else {
            return formatCompact(error: error, location: location, source: source)
        }

        let spaces = String(repeating: " ", count: location.column - 1)

        return """
        \(lineContent)
        \(spaces)^ error: \(error)
        """
    }

    @usableFromInline
    static func formatRich(error: String, location: Location, source: Source) -> String {
        var lines: [String] = []

        // Header with filename
        lines.append("================================================================================")
        if let filename = source.filename {
            lines.append("ERROR in \(filename) at line \(location.line), column \(location.column)")
        } else {
            lines.append("ERROR at line \(location.line), column \(location.column), offset \(location.offset)")
        }
        lines.append("================================================================================")
        lines.append("")
        lines.append(error)
        lines.append("")

        // Context with 3 lines
        let startLine = max(1, location.line - 3)
        let endLine = min(source.lineStarts.count, location.line + 3)

        for lineNum in startLine...endLine {
            guard let lineContent = source.line(lineNum) else { continue }

            let marker = lineNum == location.line ? ">>>" : "   "
            lines.append("\(marker) \(lineNum): \(lineContent)")

            if lineNum == location.line {
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

extension Parser.Error.LocatedError {
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

extension Parsers {
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
