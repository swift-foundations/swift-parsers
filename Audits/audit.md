# Audit: swift-parsers

## Code Surface — 2026-04-16

### Scope

- **Target**: swift-parsers
- **Skill**: code-surface — [API-NAME-001], [API-NAME-002], [API-IMPL-005], [API-IMPL-006]
- **Files**: 6 modified source files (Parsers.Identifier, Parsers.Integer, Parsers.Whitespace, Parsers.Newline, Parsers.Comment, Parsers.Quoted)

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| — | — | — | — | No violations found | — |

### Summary

0 findings. Classification refactor (2026-04-08) replaced all inline `UInt8(ascii:)` and hex literals with `.ascii.*` constants per [IMPL-060]. No compound name violations introduced. Existing API surfaces unchanged.

---

## Implementation — 2026-04-16

### Scope

- **Target**: swift-parsers
- **Skill**: implementation — [IMPL-060], [IMPL-INTENT], [IMPL-002]
- **Files**: 6 modified source files + Package.swift + exports.swift

### Findings

| # | Severity | Rule | Location | Finding | Status |
|---|----------|------|----------|---------|--------|
| 1 | — | [IMPL-060] | Parsers.Identifier.swift:85-94 | `isStartChar`/`isContinueChar` now delegate to `ASCII.Classification.isLetter`, `.isAlphanumeric` + `.ascii.underline`. | RESOLVED 2026-04-08 — was inline range checks |
| 2 | — | [IMPL-060] | Parsers.Whitespace.swift:264 | `isWhitespace` now delegates to `ASCII.Classification.isWhitespace`. Reimplemented constants deleted (-25 lines net). | RESOLVED 2026-04-08 — was 6 reimplemented constants + 6-way OR chain |
| 3 | — | [IMPL-060] | Parsers.Integer.swift | All `UInt8(ascii:)` patterns replaced with `.ascii.*` constants (22 occurrences). | RESOLVED 2026-04-08 |
| 4 | — | [IMPL-060] | Parsers.Quoted.swift | All `UInt8(ascii:)` and hex escape literals replaced with `.ascii.*` constants (16 occurrences). | RESOLVED 2026-04-08 |
| 5 | — | [IMPL-060] | Parsers.Newline.swift, Parsers.Comment.swift | Hex literals `0x0A`/`0x0D` replaced with `.ascii.lf`/`.ascii.cr`. | RESOLVED 2026-04-08 |

### Summary

0 open findings, 5 resolved. `swift-ascii-primitives` added as dependency; re-exported via `exports.swift`. All character classification and byte constants now use ecosystem primitives. Build blocked by pre-existing transitive `ISO_9945_Kernel` → `Binary_Primitives` issue (unrelated to these changes); individual targets compile cleanly.

---

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/modularization-audit-foundations-batch-B.md (2026-03-20)

**Modularization audit — MOD-001 through MOD-014**

0 FAIL. Clean compliance. 7 deps justified for parser infrastructure module.
