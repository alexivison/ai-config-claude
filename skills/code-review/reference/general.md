# Code Review Reference - General

Guidelines applicable to all code reviews.

---

## Code Review Principles

### Prerequisites
- Psychological safety must never be threatened during review
- Review the code, never the person
- Maximize team output through the review process
- Be mindful of human psychology - choose words carefully, praise good work

### Review Purpose
Focus on **code quality**:
- Readability meets team standards
- Architecture follows team conventions
- Language best practices are followed
- Style guide compliance
- Linter/formatter rules respected
- Tests included for changes
- Documentation supplements code where needed
- CI passes

### Reviewer Guidelines

1. **Don't hold back on quality issues** - Small compromises quickly erode standards
2. **Praise good code** - Balance criticism with recognition
3. **Minimize round-trips**:
   - Be explicit about expectations
   - Use labels: `[must]` (blocking), `[q]` (question), `[nit]` (suggestion)
   - Explain WHY when requesting changes
   - Complete all feedback in one pass
   - Consider synchronous communication for complex discussions
4. **Automate repeated feedback** - Use linters instead of manual comments
5. **Respond quickly** - Within one business day maximum
6. **Request PR splits** - Target 100-200 lines for effective review

---

## Coding Quality Standards

### Goals
Maintain code quality to deliver features:
- **Faster** - Quick idea-to-delivery
- **More frequently** - Rapid improvement cycles
- **Higher quality** - Natural customer problem solving
- **Longer-term** - Smooth extensibility
- **Safer** - Minimal bugs, no security concerns

### Quality Checklist

- [ ] **Consistency** - Naming, patterns, logic match surrounding code
- [ ] **High cohesion, low coupling** - Changes don't require modifications elsewhere
- [ ] **Clear naming** - Unique, concise, descriptive identifiers
- [ ] **Testable without excessive mocking**
- [ ] **Tests verify implementation** - Appropriate coverage without duplication
- [ ] **Appropriate comments** - Document non-obvious decisions, all public APIs
- [ ] **YAGNI** - No unnecessary features or complexity
- [ ] **Style guide compliance**

### Feature Flag Safety

When code uses feature flags:
- [ ] **Flag OFF = existing behavior** - Default (off) state must preserve current functionality
- [ ] **Both paths tested** - Verify behavior with flag on AND off
- [ ] **No dead code** - Remove flag and old code path after rollout complete

This is a `[must]` issue - breaking default behavior is a regression.

### AI-Generated Code
AI-generated code is treated as written by the supervisor (PR author). The supervisor takes full responsibility.

---

## PR Guidelines

### Size
- Target: Merge within one day of branch creation
- Lines: ~100-200 (excluding auto-generated code)
- Split by concern, not by test/implementation

### PR Creation
- **Title**: Clear, concise summary
- **Description**: Brief overview, link to Jira/docs/Figma
- **Reviewers**: Usually 1 person (more dilutes attention)
- **Labels**: As needed per team conventions

### During Review
- **Don't reorder commits** after review starts (breaks diff viewing)
- Commits will be squash-merged anyway

---

## Review Labels

| Label | Meaning | Use When |
|-------|---------|----------|
| `[must]` | Required | Bugs, security issues, violations - blocks approval |
| `[q]` | Question | Intent unclear, needs clarification |
| `[nit]` | Suggestion | Style preferences, optional improvements |
