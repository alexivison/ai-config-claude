# Gemini Integration Specification

## Overview

Integrate Google Gemini into the autonomous workflow as a complementary model for tasks that benefit from its unique capabilities: massive context windows (2M tokens), multimodal understanding, and fast inference.

## Goals

1. **Leverage Gemini's 2M token context** for log analysis that exceeds other models' limits
2. **Enable multimodal UI debugging** by comparing screenshots to Figma designs
3. **Add research capability** via a web search agent that synthesizes information

## Non-Goals

- Replacing existing agents (Codex, code-critic, etc.)
- Using Gemini for code review or implementation tasks
- Creating a general-purpose Gemini wrapper

## Agents

### 1. gemini-log-analyzer

**Purpose:** Analyze massive log files that exceed standard model context limits.

**Trigger:** When log analysis is needed and estimated log size > 100K tokens.

**Capabilities:**
- Ingest logs up to 2M tokens (~8MB of text)
- All existing log-analyzer capabilities (format detection, aggregation, patterns)
- Cross-reference logs from multiple sources simultaneously

**Output:** Same format as current log-analyzer (`~/.claude/logs/{identifier}.md`)

### 2. gemini-ui-debugger

**Purpose:** Compare browser screenshots against Figma designs to identify visual discrepancies.

**Trigger:** User reports UI bug, visual regression, or asks to compare implementation to design.

**Capabilities:**
- Accept screenshot (from Chrome DevTools MCP or file path)
- Fetch corresponding Figma design (via Figma MCP)
- Identify visual discrepancies: layout, spacing, colors, typography, responsive issues
- Generate structured report with specific findings and fix suggestions

**Output:** Structured findings with:
- Screenshot vs design comparison
- List of discrepancies with severity
- Suggested CSS/component fixes
- File:line references where applicable

### 3. gemini-web-search

**Purpose:** Research questions by searching the web and synthesizing results.

**Trigger:** Auto-suggested by skill-eval.sh when query needs external information.

**Capabilities:**
- Perform web searches via WebSearch tool
- Synthesize multiple search results into coherent answer
- Cite sources with URLs
- Identify when information is outdated or conflicting

**Output:** Structured research findings with sources.

## Technical Requirements

### Gemini CLI

Create a CLI wrapper similar to Codex CLI pattern:
- `gemini-cli/` directory with configuration
- `gemini-cli exec` command for invoking Gemini
- Support for image input (base64 or file path)
- Configurable model selection (Gemini 1.5 Pro, Gemini 1.5 Flash)

### Configuration

```toml
# gemini-cli/config.toml
model = "gemini-1.5-pro"
model_context_window = 2000000

[models]
default = "gemini-1.5-pro"      # For log analysis, UI debugging
fast = "gemini-1.5-flash"        # For web search synthesis

[features]
multimodal = true
```

### Integration Points

| Integration | Purpose |
|-------------|---------|
| Chrome DevTools MCP | Screenshot capture for UI debugging |
| Figma MCP | Design fetching for UI comparison |
| WebSearch tool | Web research for gemini-web-search |
| skill-eval.sh | Auto-suggest web search agent |
| agent-trace.sh | Marker creation (if needed) |

## Acceptance Criteria

1. **gemini-log-analyzer:**
   - [ ] Successfully analyzes logs > 500K tokens
   - [ ] Produces same output format as current log-analyzer
   - [ ] Falls back to standard log-analyzer for small logs

2. **gemini-ui-debugger:**
   - [ ] Accepts screenshot from file path or Chrome DevTools
   - [ ] Fetches Figma design via MCP
   - [ ] Identifies visual discrepancies with specific locations
   - [ ] Suggests actionable fixes

3. **gemini-web-search:**
   - [ ] Auto-suggested by skill-eval.sh for research queries
   - [ ] Synthesizes multiple search results
   - [ ] Cites sources with URLs
   - [ ] Returns structured findings

4. **Infrastructure:**
   - [ ] Gemini CLI wrapper functional
   - [ ] Configuration in gemini-cli/config.toml
   - [ ] Agent definitions in claude/agents/
