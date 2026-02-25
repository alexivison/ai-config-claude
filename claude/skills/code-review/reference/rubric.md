# Review Rubric

Shared severity levels and verdict model for code-review skill and code-critic agent.

## Severity Levels

- **[must]** - Bugs, security issues, maintainability violations - blocks approval
- **[q]** - Questions needing clarification - blocks approval
- **[nit]** - Minor improvements, style suggestions - non-blocking

## Verdicts

- **APPROVE** — No blocking issues (nits alone don't block)
- **REQUEST_CHANGES** — Blocking issues exist
- **NEEDS_DISCUSSION** — Max iterations hit or unresolvable disagreement
