# Audit: swift-parsers

## Legacy — Consolidated 2026-04-08

### From: swift-institute/Research/modularization-audit-foundations-batch-B.md (2026-03-20)

**Modularization audit — MOD-001 through MOD-014**

2 products: Parsers, Parsers Test Support.

| Rule | Status | Notes |
|------|--------|-------|
| MOD-001 | N/A | Main + Test Support pattern |
| MOD-002 | N/A | Single main target |
| MOD-003 | N/A | No variant targets |
| MOD-004 | N/A | No ~Copyable concerns |
| MOD-005 | N/A | Single main product |
| MOD-006 | PASS | 7 deps — includes parser primitives, machine primitives, formatting, time, source, async, clocks — all justified for a parser infrastructure module |
| MOD-007 | PASS | Depth 1 |
| MOD-008 | PASS | 13 files |
| MOD-009 | N/A | No inline variants |
| MOD-010 | N/A | No stdlib extensions observed |
| MOD-011 | PASS | Parsers Test Support published as library product |
| MOD-012 | PASS | `Parsers`, `Parsers Test Support` — correct L3 naming |
| MOD-013 | N/A | 3 targets, threshold is 5 |
| MOD-014 | N/A | No cross-package optional integration |

**Findings**: 0 FAIL. Clean compliance.
