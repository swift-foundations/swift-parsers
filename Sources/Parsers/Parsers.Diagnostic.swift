extension Parser {

    public enum Diagnostic: Sendable {}
}

extension Parser.Diagnostic {

    public struct Source: Sendable {

        public let content: String

        public let filename: String?

        @usableFromInline
        let lineStarts: [String.Index]

        public init(content: String, filename: String? = nil) {
            self.content = content
            self.filename = filename

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

    public func location(at offset: Text.Position) -> Source::Source.Location {
        let rawOffset = Int(bitPattern: offset)
        let targetIndex = content.utf8.index(
            content.utf8.startIndex,
            offsetBy: min(rawOffset, content.utf8.count)
        )

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

        let lineNumber = lo + 1
        let lineStart = lineStarts[lo]

        let column = content.utf8.distance(from: lineStart, to: targetIndex) + 1

        return Source::Source.Location(
            fileID: filename ?? "",
            line: lineNumber,
            column: column
        )
    }

    public func line(_ lineNumber: Int) -> String? {
        guard lineNumber >= 1 && lineNumber <= lineStarts.count else {
            return nil
        }

        let idx = lineNumber - 1
        let start = lineStarts[idx]
        let end: String.Index

        if idx + 1 < lineStarts.count {

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

extension Parser.Diagnostic {

    public enum Style: Sendable {

        case compact

        case expanded(contextLines: Int = 2)

        case caret

        case rich
    }
}

extension Parser.Diagnostic {

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
            return formatExpanded(
                error: errorMessage,
                location: location,
                source: source,
                contextLines: contextLines
            )

        case .caret:
            return formatCaret(error: errorMessage, location: location, source: source)

        case .rich:
            return formatRich(
                error: errorMessage,
                location: location,
                offset: offset,
                source: source
            )
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
    static func formatCompact(
        error: String,
        location: Source::Source.Location,
        source: Source
    ) -> String {
        if let filename = source.filename {
            return "\(filename):\(location.line):\(location.column): error: \(error)"
        } else {
            return "error at \(location.line):\(location.column): \(error)"
        }
    }

    @usableFromInline
    static func formatExpanded(
        error: String,
        location: Source::Source.Location,
        source: Source,
        contextLines: Int
    ) -> String {

        let lineInt: Int = Int(location.line.underlying)
        var lines: [String] = []

        if let filename = source.filename {
            lines.append("error: \(error)")
            lines.append("  --> \(filename):\(location.line):\(location.column)")
        } else {
            lines.append("error: \(error)")
            lines.append("  --> line \(location.line), column \(location.column)")
        }
        lines.append("   |")

        let startLine = max(1, lineInt - contextLines)
        let endLine = min(source.lineStarts.count, lineInt + contextLines)

        for lineNum in startLine...endLine {
            guard let lineContent = source.line(lineNum) else { continue }

            let lineNumStr = padLeft(String(lineNum), toLength: 3)

            if lineNum == lineInt {
                lines.append(" \(lineNumStr)| \(lineContent)")

                let columnInt = Int(bitPattern: location.column)
                let spaces = String(repeating: " ", count: columnInt - 1)
                lines.append("   | \(spaces)^")
            } else {
                lines.append(" \(lineNumStr)| \(lineContent)")
            }
        }

        lines.append("   |")
        return lines.joined(separator: "\n")
    }

    @usableFromInline
    static func formatCaret(
        error: String,
        location: Source::Source.Location,
        source: Source
    ) -> String {

        guard let lineContent = source.line(Int(location.line.underlying)) else {
            return formatCompact(error: error, location: location, source: source)
        }

        let columnInt = Int(bitPattern: location.column)
        let spaces = String(repeating: " ", count: columnInt - 1)

        return """
            \(lineContent)
            \(spaces)^ error: \(error)
            """
    }

    @usableFromInline
    static func formatRich(
        error: String,
        location: Source::Source.Location,
        offset: Text.Position,
        source: Source
    ) -> String {

        let lineInt: Int = Int(location.line.underlying)
        var lines: [String] = []

        lines.append(
            "================================================================================"
        )
        if let filename = source.filename {
            lines.append("ERROR in \(filename) at line \(location.line), column \(location.column)")
        } else {
            lines.append(
                "ERROR at line \(location.line), column \(location.column), offset \(offset)"
            )
        }
        lines.append(
            "================================================================================"
        )
        lines.append("")
        lines.append(error)
        lines.append("")

        let startLine = max(1, lineInt - 3)
        let endLine = min(source.lineStarts.count, lineInt + 3)

        for lineNum in startLine...endLine {
            guard let lineContent = source.line(lineNum) else { continue }

            let marker = lineNum == lineInt ? ">>>" : "   "
            lines.append("\(marker) \(lineNum): \(lineContent)")

            if lineNum == lineInt {

                let spaces = String(
                    repeating: " ",
                    count: String(lineNum).count + 5 + Int(bitPattern: location.column)
                )
                lines.append("\(spaces)^^^")
            }
        }

        lines.append("")
        lines.append(
            "================================================================================"
        )

        return lines.joined(separator: "\n")
    }
}

extension Parser.Error.Located {

    public func formatted(
        in source: Parser.Diagnostic.Source,
        style: Parser.Diagnostic.Style = .expanded()
    ) -> String {
        Parser.Diagnostic.format(self, at: offset, in: source, style: style)
    }
}

extension Parser {

    @inlinable
    public static var diagnostic: Diagnostic.Type { Diagnostic.self }
}
