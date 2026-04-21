# Severity & Verdict Reference

## Severity Labels

| Label | Meaning | Blocks? |
|-------|---------|---------|
| `[must]` | Correctness bug, security issue, data loss risk, principle violation | Yes |
| `[q]` | Question, debatable design, clarification needed | No |
| `[nit]` | Style, minor improvement, optional polish | No |

**Variants:** deep-reviewer and requirements-auditor use `[should]` instead of `[q]` for robustness gaps / minor scope creep.

## Verdicts

| Verdict | When |
|---------|------|
| **APPROVE** | No `[must]` findings |
| **REQUEST_CHANGES** | One or more `[must]` findings |
| **NEEDS_DISCUSSION** | Architectural concerns, unclear requirements, persistent blocking findings |

requirements-auditor and deep-reviewer use only APPROVE / REQUEST_CHANGES (no NEEDS_DISCUSSION).

Human prose uses `APPROVE / REQUEST_CHANGES / NEEDS_DISCUSSION`. Inter-agent findings files use `VERDICT: APPROVED` / `VERDICT: REQUEST_CHANGES`.

Mapping: `APPROVE` in prose corresponds to `VERDICT: APPROVED` in a findings file. Use the `VERDICT:` spelling only inside machine-read findings files.

## Default Suppression

`[q]` and `[nit]` are opt-in — suppress by default unless explicitly requested. Critics should APPROVE when only non-blocking findings remain.
