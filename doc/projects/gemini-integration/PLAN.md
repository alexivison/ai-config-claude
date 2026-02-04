# Gemini Integration Implementation Plan

> **Goal:** Add Gemini-powered agents for large-scale log analysis, UI debugging, and web research.
>
> **Architecture:** Use existing Gemini CLI (already installed and authenticated) invoked by dedicated agents. Each agent handles a specific use case leveraging Gemini's unique capabilities (2M context, multimodal, fast inference).
>
> **Tech Stack:** Gemini CLI, existing MCP tools (Figma, Chrome DevTools)
>
> **Specification:** [SPEC.md](./SPEC.md) | **Design:** [DESIGN.md](./DESIGN.md)

## Task Overview

| Task | Description | Dependencies |
|------|-------------|--------------|
| TASK0 | Gemini CLI configuration | None |
| TASK1 | gemini-log-analyzer agent | TASK0 |
| TASK2 | gemini-ui-debugger agent | TASK0 |
| TASK3 | gemini-web-search agent | TASK0 |
| TASK4 | skill-eval.sh integration | TASK3 |
| TASK5 | Documentation updates | TASK1, TASK2, TASK3 |

## Dependency Graph

```
TASK0 (CLI config)
  │
  ├──► TASK1 (log-analyzer)
  │         │
  ├──► TASK2 (ui-debugger)
  │         │
  └──► TASK3 (web-search)
            │
            ▼
      TASK4 (skill-eval.sh)
            │
            ▼
      TASK5 (documentation)
```

## Task Details

### TASK0: Gemini CLI Configuration
- [ ] Verify CLI is installed and authenticated
- [ ] Create `gemini/AGENTS.md` instructions

**Deliverables:** Verified CLI + agent instructions

### TASK1: gemini-log-analyzer Agent
- [ ] Create `claude/agents/gemini-log-analyzer.md`
- [ ] Implement size estimation logic
- [ ] Add fallback to standard log-analyzer
- [ ] Test with large log files

**Deliverables:** Agent that handles logs > 100K tokens

### TASK2: gemini-ui-debugger Agent
- [ ] Create `claude/agents/gemini-ui-debugger.md`
- [ ] Implement screenshot capture flow
- [ ] Implement Figma design fetching
- [ ] Create comparison prompt template
- [ ] Define output format for discrepancies

**Deliverables:** Agent that compares screenshots to Figma designs

### TASK3: gemini-web-search Agent
- [ ] Create `claude/agents/gemini-web-search.md`
- [ ] Implement search query formulation
- [ ] Add result synthesis logic
- [ ] Define citation format

**Deliverables:** Agent that researches and synthesizes web results

### TASK4: skill-eval.sh Integration
- [ ] Add web search trigger patterns
- [ ] Test auto-suggestion behavior
- [ ] Ensure no conflicts with existing patterns

**Deliverables:** Auto-suggestion for research queries

### TASK5: Documentation Updates
- [ ] Update `claude/agents/README.md` with new agents
- [ ] Update `claude/CLAUDE.md` sub-agents table

**Deliverables:** Complete documentation for new capabilities

## Implementation Notes

### Gemini CLI Usage Pattern

The Gemini CLI is already installed at `/Users/aleksituominen/.nvm/versions/node/v24.12.0/bin/gemini`:

| Codex CLI | Gemini CLI |
|-----------|------------|
| `codex exec -s read-only "..."` | `gemini --approval-mode plan -p "..."` |
| Model selection | `gemini -m gemini-2.0-flash -p "..."` |
| Large input | `cat logs \| gemini -p "Analyze..."` |

### Testing Strategy

| Agent | Test Approach |
|-------|---------------|
| gemini-log-analyzer | Generate large synthetic log, verify analysis |
| gemini-ui-debugger | Use known screenshot + Figma with intentional differences |
| gemini-web-search | Query with known answer, verify synthesis quality |

### Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Gemini API rate limits | CLI handles retry internally |
| Multimodal support | Use Gemini API directly via curl + base64 |
| Context overflow | Truncate with clear warning |
