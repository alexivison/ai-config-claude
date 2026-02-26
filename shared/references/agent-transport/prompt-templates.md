# Prompt Templates

Shared templates for cross-agent review and task delegation via tmux transport scripts.

## 1) Plan Review

```text
Review {PLAN_PATH} for architecture soundness and execution feasibility.

Evaluate:
1) requirement clarity and measurable acceptance criteria
2) dependency ordering and sequencing risks
3) cross-task consistency and end-state coherence
4) missing verification commands and quality gates

Write TOON findings to: {FINDINGS_FILE}
Use findings[N]{id,file,line,severity,category,description,suggestion}; no verdict.
```

## 2) Code Review

```text
Review the current uncommitted changes for correctness, security, and maintainability.

Prioritize:
1) regressions/behavioral bugs
2) security/data handling flaws
3) architecture and complexity issues

Write TOON findings to: {FINDINGS_FILE}
Use findings[N]{id,file,line,severity,category,description,suggestion}; no verdict.
```

## 3) Design Trade-off

```text
Compare options:
A) {OPTION_A}
B) {OPTION_B}

Criteria:
1) implementation complexity
2) maintainability
3) operational risk
4) performance characteristics

Return:
- pros/cons matrix
- recommended option
- 3 key risks and mitigations
```

## 4) Structured JSON Result

```text
Task: {TASK}
Constraints: {CONSTRAINTS}

Return only JSON matching the provided schema.
No prose outside JSON.
```
