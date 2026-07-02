# swift-parsers

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Batteries-included parsers for the recurring shapes in text formats — integers in four bases, quoted strings with escape handling, identifiers, whitespace, newlines, comments, and expression parsing with precedence climbing.

## Overview

swift-parsers is a single-import convenience layer over the parsing infrastructure in [swift-primitives](https://github.com/swift-primitives). `import Parsers` re-exports the underlying parser modules (`Parser_Primitives`, `Parser_Machine_Primitives`, `ASCII_Primitives`, `Format_Primitives`, `Time_Primitives`, `Source_Primitives`, and `Async`) and adds ready-made parsers for the token shapes that nearly every text format needs, so you compose grammars instead of rewriting byte-scanning loops.

Every parser is a small `Sendable` struct conforming to `Parser.Protocol`: it consumes from an `inout Substring.UTF8View` and throws a typed, parser-specific error on failure — no `any Error` anywhere in the surface.

## Quick Start

CSV- and SQL-style strings escape a literal quote by doubling it. Hand-rolled scanners routinely get the lookahead wrong at `""` versus end-of-string; `Parser.Quoted.Doubling` handles it and leaves the input positioned after the closing quote:

```swift
import Parsers

var input = "\"say \"\"hi\"\"\",next"[...].utf8

let field = try Parser.Quoted.Doubling().parse(&input)
// field == "say \"hi\""
// input rests at: ,next
```

Overflow-checked integer parsing into any `FixedWidthInteger`, with the base and prefix policy stated in the type rather than re-derived from string inspection:

```swift
import Parsers

var hex = "0xFF"[...].utf8
let color = try Parser.Integer<UInt32>.Hexadecimal(requirePrefix: true).parse(&hex)
// color == 255

var count = "007"[...].utf8
let value = try Parser.Integer<Int>.Decimal(allowLeadingZeros: true).parse(&count)
// value == 7 — a value that overflows Int throws .overflow instead of trapping
```

## Installation

Add swift-parsers to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-parsers.git", branch: "main")
]
```

Add the product to your target:

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Parsers", package: "swift-parsers")
    ]
)
```

### Requirements

- Swift 6.3+
- macOS 26+, iOS 26+, tvOS 26+, watchOS 26+, visionOS 26+

## Usage Examples

### Expression parsing with precedence climbing

Operator precedence is the classic place where recursive-descent parsers sprawl into one grammar rule per precedence level. `Parser.Expression.Climbing` takes an atom parser plus a declarative operator table and handles precedence, associativity, and optional prefix/postfix operators in one pass:

```swift
import Parsers

// An operator token parser: matches a single ASCII byte.
struct Symbol: Parser.`Protocol`, Sendable {
    typealias Input = Substring.UTF8View
    typealias Output = Void
    typealias Failure = Parser.Match.Error

    let byte: UInt8

    func parse(_ input: inout Input) throws(Failure) -> Void {
        guard input.first == byte else {
            throw .predicateFailed(description: "operator")
        }
        input.removeFirst()
    }
}

let arithmetic = Parser.Expression.Climbing(
    atom: Parser.Integer<Int>.Decimal(allowSign: false),
    operators: [
        .init(parser: Symbol(byte: UInt8(ascii: "+")), precedence: 1, associativity: .left) { $0 + $1 },
        .init(parser: Symbol(byte: UInt8(ascii: "-")), precedence: 1, associativity: .left) { $0 - $1 },
        .init(parser: Symbol(byte: UInt8(ascii: "*")), precedence: 2, associativity: .left) { $0 * $1 },
    ]
)

var input = "10-2*3"[...].utf8
let value = try arithmetic.parse(&input)
// value == 4 — multiplication binds tighter than subtraction
```

`Parser.Chain.Left` and `Parser.Chain.Right` are the lighter alternatives when all operators share one precedence level.

### Structural combinators

`Parser.Separated` parses delimiter-separated sequences with count constraints and trailing-separator policy; `Parser.Between` parses content between open and close delimiters — both generic over any element parsers that share an input type.

### Line-oriented lexing

```swift
import Parsers

var line = "//  configuration block\n"[...].utf8

// Consume the comment up to (not including) the newline …
_ = try Parser.Comment.Line(prefix: "//").parse(&line)

// … then the newline, accepting LF, CR, or CRLF.
try Parser.Newline.Any().parse(&line)
```

Whitespace handling is split by direction — `Parser.Whitespace.Horizontal` (spaces, tabs), vertical newline parsers per style (`LF`, `CR`, `CRLF`), and skip variants — so line-oriented formats state exactly what they accept. `Parser.Identifier.CStyle` matches `[a-zA-Z_][a-zA-Z0-9_]*`, and `Parser.Comment.Block` supports nested block comments.

### Diagnostics and debugging

`Parser.Diagnostic.Source` maps byte offsets in failed parses to line/column locations and formats errors with source snippets and carets. `Parser.Debug.Trace` and `Parser.Debug.Profile` wrap any parser with entry/exit logging or invocation-timing statistics without changing its behavior.

## Architecture

Single library module plus a test-support product:

| Product | When to import |
|---------|----------------|
| `Parsers` | Applications and libraries composing parsers; re-exports the underlying parser primitives so one import suffices |
| `Parsers Test Support` | Test targets exercising parsers built on this package |

| Namespace | Purpose |
|-----------|---------|
| `Parser.Integer<Output>` | `Decimal`, `Hexadecimal`, `Binary`, `Octal` — overflow-checked, generic over `FixedWidthInteger` |
| `Parser.Quoted` | `Double`, `Single`, `Doubling` — quoted strings with backslash or doubling escapes |
| `Parser.Identifier` | `CStyle` and custom identifier classes |
| `Parser.Whitespace`, `Parser.Newline` | Horizontal/vertical whitespace; LF, CR, CRLF, and universal newline parsers |
| `Parser.Comment` | `Line` (`//`, `#`, `--`, …) and `Block` (`/* … */`, optionally nested) |
| `Parser.Separated`, `Parser.Between` | Delimiter-separated sequences; content between delimiters |
| `Parser.Chain`, `Parser.Expression` | Left/right-associative operator chains; precedence climbing |
| `Parser.Diagnostic` | Line/column source locations, formatted error messages |
| `Parser.Debug` | `Trace` and `Profile` instrumentation wrappers |

## Error Handling

Each parser family throws its own typed error, so `catch` arms are exhaustive per parser rather than matched against a shared catch-all:

| Parser family | Error type | Cases |
|---------------|-----------|-------|
| `Parser.Integer` | `Parser.Integer<Output>.Error` | `.noDigits`, `.overflow`, `.invalidDigit`, `.missingPrefix` |
| `Parser.Quoted` | `Parser.Quoted.Error` | `.missingOpenQuote`, `.unterminatedString`, `.invalidEscape`, `.unexpectedNewline` |
| `Parser.Comment.Block` | `Parser.Comment.Block.Error` | `.missingOpen`, `.unterminatedComment` |
| `Parser.Identifier`, `Parser.Newline`, `Parser.Comment.Line` | `Parser.Match.Error` | Predicate and match failures |
| `Parser.Whitespace` | `Parser.Constraint.Error` | Count-constraint failures |

```swift
import Parsers

var input = "\"unterminated"[...].utf8

do {
    _ = try Parser.Quoted.Double().parse(&input)
} catch .missingOpenQuote {
    // No opening quote at the current position
} catch .unterminatedString {
    // Opened but never closed
} catch .invalidEscape(let sequence) {
    // Unknown escape sequence, e.g. \q
} catch .unexpectedNewline {
    // Literal newline inside a single-line string
}
```

Combinators propagate their constituent parsers' typed errors — for example, `Parser.Expression.Climbing`'s failure type is its atom parser's failure type.

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public flip.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md) for details.
